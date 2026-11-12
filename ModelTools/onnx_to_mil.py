"""Development-only ONNX -> MIL lowering for the hash-pinned Metra graphs.

This is not a general ONNX converter. export-models.py verifies the six source
files before using this frontend. Singleton view axes are omitted losslessly to
satisfy the Core ML rank limit; numerical parity is checked separately.
"""
from pathlib import Path
import argparse
import json
import hashlib
import numpy as np
import onnx
from onnx import numpy_helper, helper
import coremltools as ct
from coremltools.converters.mil import Builder as mb
from coremltools.converters.mil.mil import Program, Function, Placeholder, types, Var


def value(x):
    return x.val if isinstance(x, Var) else x


def array(x):
    v = value(x)
    if v is None:
        raise ValueError("Expected a compile-time constant")
    return np.asarray(v)


def ints(x):
    return [int(v) for v in array(x).reshape(-1)]


def normalized(x):
    x = np.asarray(x)
    if x.dtype == np.int64:
        x = np.clip(x, np.iinfo(np.int32).min, np.iinfo(np.int32).max).astype(np.int32)
    if x.dtype == np.float64:
        x = x.astype(np.float32)
    return x


DTYPES = {1: 'fp32', 6: 'int32', 7: 'int32', 9: 'bool', 10: 'fp16', 11: 'fp32'}


class LogicalTensor:
    """Represent rank-six views with singleton axes omitted from physical storage."""
    def __init__(self,tensor,shape,omitted=(0,)):
        self.tensor=tensor;self.shape=tuple(shape);self.omitted=tuple(omitted)
        self.dtype=tensor.dtype


def logical_reshape(x,shape):
    physical=x.tensor if isinstance(x,LogicalTensor) else x
    dims=ints(shape)
    dims=[x.shape[i] if d==0 else d for i,d in enumerate(dims)]
    if -1 in dims:
        dims[dims.index(-1)]=int(np.prod(x.shape))//int(-np.prod(dims))
    if len(dims)>5:
        omitted=[]
        for i,d in enumerate(dims):
            if d==1 and len(dims)-len(omitted)>5:omitted.append(i)
        if len(dims)-len(omitted)>5:raise ValueError(('Cannot lower non-singleton high-rank view',dims))
        return LogicalTensor(mb.reshape(x=physical,shape=[d for i,d in enumerate(dims) if i not in omitted]),dims,omitted)
    return mb.reshape(x=physical,shape=dims)


def lower(node, xs, opset):
    a = {v.name: helper.get_attribute_value(v) for v in node.attribute}
    op = node.op_type
    x = xs[0] if xs else None
    views=[v for v in xs if isinstance(v,LogicalTensor)]
    if views and op!='Reshape':
        view=views[0]
        if op=='Shape':return np.array(view.shape,np.int32)
        if op=='Identity':return x
        if op=='Transpose':
            perm=a.get('perm',list(reversed(range(len(view.shape)))))
            kept=[i for i in range(len(view.shape)) if i not in view.omitted]
            out=mb.transpose(x=view.tensor,perm=[kept.index(i) for i in perm if i in kept])
            return LogicalTensor(out,[view.shape[i] for i in perm],[perm.index(i) for i in view.omitted])
        if op in ['Add','Sub','Mul','Div','Cast','Sigmoid','Relu']:
            if view.omitted!=(0,):raise ValueError('Unsupported broadcast with internal omitted dimension')
            shape=np.broadcast_shapes(*(v.shape for v in xs if v is not None))
            return LogicalTensor(lower(node,[v.tensor if isinstance(v,LogicalTensor) else v for v in xs],opset),shape,view.omitted)
        if op=='Slice':
            axes=ints(xs[3]) if len(xs)>3 else a.get('axes',list(range(len(ints(xs[1])))))
            if any(axis%len(view.shape) in view.omitted for axis in axes):raise ValueError('Slice on an omitted unit axis')
            kept=[i for i in range(len(view.shape)) if i not in view.omitted]
            args=list(xs);args[0]=view.tensor
            while len(args)<4:args.append(None)
            args[3]=np.array([kept.index(axis%len(view.shape)) for axis in axes],np.int32)
            out=lower(node,args,opset)
            logical=list(out.shape)
            for axis in view.omitted:logical.insert(axis,1)
            return LogicalTensor(out,logical,view.omitted)
        if op=='Squeeze':
            axes=ints(xs[1]) if len(xs)>1 else a.get('axes')
            axes=[axis%len(view.shape) for axis in axes]
            if any(view.shape[axis]!=1 for axis in axes):raise ValueError('Squeeze nonunit logical axis')
            logical=[d for i,d in enumerate(view.shape) if i not in axes]
            return logical_reshape(view,np.array(logical,np.int32))
        raise ValueError(('Unsupported logical tensor consumer',op,view.shape))
    if op == 'Constant':
        return normalized(numpy_helper.to_array(a['value']))
    if op == 'Identity':
        return x
    if op == 'Cast':
        return mb.cast(x=x, dtype=DTYPES[a['to']])
    binary = {'Add':'add', 'Sub':'sub', 'Mul':'mul', 'Div':'real_div', 'Pow':'pow',
              'Equal':'equal', 'Greater':'greater', 'Less':'less', 'And':'logical_and'}
    if op in binary:
        # ONNX integer division truncates toward zero; these graphs divide nonnegative shapes.
        fn = 'floor_div' if op == 'Div' and ((isinstance(x,Var) and x.dtype == types.int32) or (not isinstance(x,Var) and np.asarray(x).dtype.kind in 'iu')) else binary[op]
        return getattr(mb,fn)(x=x,y=xs[1])
    unary = {'Relu':'relu','Sigmoid':'sigmoid','Sqrt':'sqrt','Erf':'erf','Floor':'floor','Log':'log','Neg':'neg','Abs':'abs'}
    if op in unary:
        return getattr(mb,unary[op])(x=x)
    if op == 'HardSigmoid':
        return mb.sigmoid_hard(x=x,alpha=a.get('alpha',0.2),beta=a.get('beta',0.5))
    if op == 'Mod':
        if a.get('fmod',0): raise ValueError('fmod is not implemented')
        return mb.mod(x=x,y=xs[1])
    if op in ['Max','Min']:
        result = x
        for y in xs[1:]: result = getattr(mb,'maximum' if op=='Max' else 'minimum')(x=result,y=y)
        return result
    if op == 'Where':
        return mb.select(cond=x,a=xs[1],b=xs[2])
    if op == 'Clip':
        lo = float(array(xs[1])) if len(xs)>1 and xs[1] is not None else a.get('min',-np.finfo(np.float32).max)
        hi = float(array(xs[2])) if len(xs)>2 and xs[2] is not None else a.get('max',np.finfo(np.float32).max)
        return mb.clip(x=x,alpha=lo,beta=hi)
    if op == 'Conv':
        rank = len(x.shape)-2
        pads = a.get('pads',[0]*(rank*2))
        kwargs = dict(x=x,weight=xs[1],strides=a.get('strides',[1]*rank),
                      dilations=a.get('dilations',[1]*rank),groups=a.get('group',1),
                      pad_type='custom',pad=[p for pair in zip(pads[:rank],pads[rank:]) for p in pair])
        if len(xs)>2: kwargs['bias']=xs[2]
        auto = a.get('auto_pad',b'NOTSET')
        if auto not in [b'NOTSET',b'VALID']:
            if auto != b'SAME_UPPER': raise ValueError(auto)
            kwargs['pad_type']='same';kwargs.pop('pad')
        return mb.conv(**kwargs)
    if op == 'BatchNormalization':
        return mb.batch_norm(x=x,gamma=xs[1],beta=xs[2],mean=xs[3],variance=xs[4],epsilon=a.get('epsilon',1e-5))
    if op == 'LayerNormalization':
        axis=a.get('axis',-1)%len(x.shape)
        kw=dict(x=x,axes=list(range(axis,len(x.shape))),epsilon=a.get('epsilon',1e-5))
        if len(xs)>1:kw['gamma']=xs[1]
        if len(xs)>2:kw['beta']=xs[2]
        return mb.layer_norm(**kw)
    if op in ['MaxPool','AveragePool']:
        if a.get('dilations',[1,1]) != [1,1]: raise ValueError('pool dilation')
        pads=a.get('pads',[0,0,0,0])
        kw=dict(x=x,kernel_sizes=a['kernel_shape'],strides=a.get('strides',[1,1]),
                pad_type='custom',pad=[pads[0],pads[2],pads[1],pads[3]],ceil_mode=bool(a.get('ceil_mode',0)))
        if a.get('auto_pad',b'NOTSET') == b'SAME_UPPER':
            kw['pad_type']='same';kw['ceil_mode']=False;kw.pop('pad')
        if op=='AveragePool':kw['exclude_padding_from_average']=not bool(a.get('count_include_pad',0))
        return getattr(mb,'max_pool' if op=='MaxPool' else 'avg_pool')(**kw)
    if op == 'GlobalAveragePool':
        return mb.reduce_mean(x=x,axes=list(range(2,len(x.shape))),keep_dims=True)
    if op == 'MatMul':
        return mb.matmul(x=x,y=xs[1])
    if op == 'Transpose':
        return mb.transpose(x=x,perm=a.get('perm',list(reversed(range(len(x.shape))))))
    if op == 'Reshape':
        if a.get('allowzero',0): raise ValueError('allowzero')
        shape=xs[1]
        if isinstance(x,LogicalTensor) or (shape.shape[0]>5):
            return logical_reshape(x,shape)
        symbolic=shape.sym_val if isinstance(shape,Var) else shape
        if symbolic is not None and any(v == 0 for v in symbolic):
            own=mb.shape(x=x); parts=[]
            for i,v in enumerate(symbolic):
                parts.append(mb.slice_by_index(x=own if v == 0 else shape,begin=[i],end=[i+1]))
            shape=mb.concat(values=parts,axis=0)
        return mb.reshape(x=x,shape=shape)
    if op == 'Flatten':
        axis=a.get('axis',1)
        shape=mb.shape(x=x)
        left=mb.reduce_prod(x=mb.slice_by_index(x=shape,begin=[0],end=[axis]),keep_dims=True)
        right=mb.reduce_prod(x=mb.slice_by_index(x=shape,begin=[axis],end=[len(x.shape)]),keep_dims=True)
        return mb.reshape(x=x,shape=mb.concat(values=[left,right],axis=0))
    if op == 'Shape':
        y=mb.shape(x=x)
        if 'start' in a or 'end' in a:
            y=mb.slice_by_index(x=y,begin=[a.get('start',0)],end=[a.get('end',len(x.shape))])
        return y
    if op in ['Unsqueeze','Squeeze']:
        axes=ints(xs[1]) if len(xs)>1 else a.get('axes')
        if axes is None:return mb.squeeze(x=x)
        if op=='Unsqueeze' and len(x.shape)+len(axes)>5:
            rank=len(x.shape)+len(axes);axes=[axis%rank for axis in axes]
            logical=list(x.shape)
            for axis in sorted(axes):logical.insert(axis,1)
            return logical_reshape(x,np.array(logical,np.int32))
        return getattr(mb,'expand_dims' if op=='Unsqueeze' else 'squeeze')(x=x,axes=axes)
    if op == 'Concat':
        return mb.concat(values=xs,axis=a['axis'])
    if op == 'Split':
        sizes=ints(xs[1]) if len(xs)>1 else a.get('split')
        kw=dict(x=x,axis=a.get('axis',0))
        if sizes is not None:kw['split_sizes']=sizes
        else:kw['num_splits']=len(node.output)
        return mb.split(**kw)
    if op == 'Slice':
        starts=xs[1] if len(xs)>1 else np.array(a['starts'],np.int32)
        ends=xs[2] if len(xs)>2 else np.array(a['ends'],np.int32)
        axes=ints(xs[3]) if len(xs)>3 and xs[3] is not None else a.get('axes',list(range(len(value(starts)))))
        steps=ints(xs[4]) if len(xs)>4 and xs[4] is not None else [1]*len(axes)
        rank=len(x.shape)
        def expanded(v,default):
            parts=[]
            for i in range(rank):
                idx=next((j for j,axis in enumerate(axes) if axis%rank==i),None)
                parts.append(np.array([default],np.int32) if idx is None else mb.slice_by_index(x=v,begin=[idx],end=[idx+1]))
            return mb.concat(values=parts,axis=0) if len(parts)>1 else parts[0]
        begin=expanded(starts,0);end=expanded(ends,0)
        stride=[1]*rank;begin_mask=[True]*rank;end_mask=[True]*rank
        sv=value(starts);ev=value(ends)
        for j,axis in enumerate(axes):
            stride[axis%rank]=steps[j];begin_mask[axis%rank]=False;end_mask[axis%rank]=False
            if ev is not None and abs(int(np.asarray(ev).reshape(-1)[j]))>=np.iinfo(np.int32).max: end_mask[axis%rank]=True
            if sv is not None and abs(int(np.asarray(sv).reshape(-1)[j]))>=np.iinfo(np.int32).max: begin_mask[axis%rank]=True
        return mb.slice_by_index(x=x,begin=begin,end=end,stride=stride,begin_mask=begin_mask,end_mask=end_mask)
    if op == 'Gather':
        return mb.gather(x=x,indices=xs[1],axis=a.get('axis',0))
    if op == 'GatherND':
        return mb.gather_nd(x=x,indices=xs[1],batch_dims=a.get('batch_dims',0))
    if op == 'Expand':
        # ONNX Expand uses multidirectional broadcasting, including requested dimensions of 1.
        shape=xs[1]
        if len(x.shape)>0:
            own=mb.shape(x=x)
            if shape.shape[0]>len(x.shape): own=mb.concat(values=[np.ones(shape.shape[0]-len(x.shape),np.int32),own],axis=0)
            shape=mb.maximum(x=shape,y=own)
        dtype=x.dtype if isinstance(x,Var) else types.numpy_type_to_builtin_type(np.asarray(x).dtype)
        if dtype == types.bool:
            return mb.logical_or(x=x,y=mb.cast(x=mb.fill(shape=shape,value=0),dtype='bool'))
        return mb.add(x=x,y=mb.fill(shape=shape,value=np.int32(0) if dtype == types.int32 else np.float32(0)))
    if op == 'Tile':
        return mb.tile(x=x,reps=xs[1])
    if op == 'ConstantOfShape':
        val=normalized(numpy_helper.to_array(a['value'])).reshape(-1)[0] if 'value' in a else np.float32(0)
        return mb.fill(shape=x,value=val)
    if op == 'Range':
        return mb.range_1d(start=x,end=xs[1],step=xs[2])
    if op.startswith('Reduce'):
        axes=ints(xs[1]) if len(xs)>1 else a.get('axes',list(range(len(x.shape))))
        fn={'ReduceMean':'reduce_mean','ReduceSum':'reduce_sum','ReduceMax':'reduce_max','ReduceProd':'reduce_prod'}[op]
        return getattr(mb,fn)(x=x,axes=axes,keep_dims=bool(a.get('keepdims',1)))
    if op == 'Softmax':
        axis=a.get('axis',-1 if opset>=13 else 1)
        if opset<13 and axis%len(x.shape)!=len(x.shape)-1:
            shape=mb.shape(x=x); y=mb.reshape(x=x,shape=[-1,int(np.prod(x.shape[axis:]))])
            return mb.reshape(x=mb.softmax(x=y,axis=-1),shape=shape)
        return mb.softmax(x=x,axis=axis)
    if op == 'Pad':
        pads=ints(xs[1]) if len(xs)>1 else a['pads']; rank=len(x.shape)
        mode=a.get('mode',b'constant').decode()
        kwargs=dict(x=x,pad=[p for pair in zip(pads[:rank],pads[rank:]) for p in pair],mode=mode)
        if mode=='constant':kwargs['constant_val']=float(array(xs[2])) if len(xs)>2 and xs[2] is not None else a.get('value',0.)
        return mb.pad(**kwargs)
    if op == 'GridSample':
        return mb.resample(x=x,coordinates=xs[1],sampling_mode=a.get('mode',b'bilinear').decode(),
                           padding_mode={b'zeros':'constant',b'border':'border',b'reflection':'reflection'}[a.get('padding_mode',b'zeros')],
                           padding_value=0.,coordinates_mode='normalized_minus_one_to_one',align_corners=bool(a.get('align_corners',0)))
    if op == 'Resize':
        scales=array(xs[2]) if len(xs)>2 and xs[2] is not None else None
        if scales is None or scales.size==0:
            sizes=ints(xs[3]); scales=np.asarray(sizes)/np.asarray(x.shape)
        if not np.array_equal(scales[:2],[1,1]):raise ValueError('Resize batch/channels')
        mode=a.get('mode',b'nearest'); coord=a.get('coordinate_transformation_mode',b'half_pixel')
        if mode==b'nearest':
            if coord not in [b'asymmetric',b'half_pixel'] or a.get('nearest_mode',b'round_prefer_floor') not in [b'floor',b'round_prefer_floor']:
                raise ValueError(('nearest resize mode',a))
            return mb.upsample_nearest_neighbor(x=x,scale_factor_height=float(scales[2]),scale_factor_width=float(scales[3]))
        if mode==b'linear' and coord in [b'half_pixel',b'align_corners']:
            return mb.upsample_bilinear(x=x,scale_factor_height=float(scales[2]),scale_factor_width=float(scales[3]),align_corners=coord==b'align_corners')
        raise ValueError(('resize',a))
    if op == 'TopK':
        return mb.topk(x=x,k=int(array(xs[1]).reshape(-1)[0]),axis=a.get('axis',-1),ascending=not bool(a.get('largest',1)),sort=bool(a.get('sorted',1)))
    raise NotImplementedError(op)


def convert(source,destination,shapes,fp16=False):
    graph=onnx.load(str(source))
    opset=next(v.version for v in graph.opset_import if v.domain=='')
    inputs={}
    specs=[]
    for inp in graph.graph.input:
        shape=shapes[inp.name]
        dims=[ct.RangeDim(*d) if isinstance(d,list) else d for d in shape]
        dtype=types.int32 if inp.type.tensor_type.elem_type in [6,7] else types.fp32
        inputs[inp.name]=Placeholder(tuple(d.symbol if isinstance(d,ct.RangeDim) else d for d in dims),dtype=dtype)
        specs.append(ct.TensorType(name=inp.name,shape=tuple(dims),dtype=np.int32 if dtype==types.int32 else np.float32))
    program=Program()
    with Function(inputs,opset_version=ct.target.iOS18) as function:
        env={v.name:normalized(numpy_helper.to_array(v)) for v in graph.graph.initializer}
        env.update(function.inputs)
        for i,node in enumerate(graph.graph.node):
            try:
                out=lower(node,[env[v] if v else None for v in node.input],opset)
                outs=list(out) if isinstance(out,(tuple,list)) else [out]
                for name,result in zip(node.output,outs):
                    if name:env[name]=mb.const(val=normalized(result)) if isinstance(result,np.ndarray) else result
            except Exception:
                print('FAILED',i,node.op_type,node.name,'INPUTS',[(n, getattr(env.get(n),'shape',None)) for n in node.input],flush=True)
                raise
            if i%1000==0:print('LOWERED',i,len(graph.graph.node),flush=True)
        function.set_outputs([mb.identity(x=env[v.name],name=v.name) for v in graph.graph.output])
    program.add_function('main',function)
    model=ct.convert(program,source='milinternal',convert_to='mlprogram',inputs=specs,
                     minimum_deployment_target=ct.target.iOS18,
                     compute_precision=ct.precision.FLOAT16 if fp16 else ct.precision.FLOAT32,
                     compute_units=ct.ComputeUnit.CPU_ONLY,skip_model_load=True)
    model.user_defined_metadata['metra.source.sha256']=hashlib.sha256(Path(source).read_bytes()).hexdigest()
    model.user_defined_metadata['metra.source.format']='ONNX'
    model.user_defined_metadata['metra.precision']='FP16' if fp16 else 'FP32'
    model.short_description='Metra on-device extraction model; no Python or ONNX runtime required.'
    model.save(str(destination))
    print('SAVED',destination,flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('source',type=Path);parser.add_argument('destination',type=Path)
    parser.add_argument('--shapes',required=True);parser.add_argument('--fp16',action='store_true')
    args=parser.parse_args()
    convert(args.source,args.destination,json.loads(args.shapes),args.fp16)
