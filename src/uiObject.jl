using CEnum

export UIObject, render, UIRenderType

@cenum UIRenderType begin
	UI_VISIBLE = 1
	UI_SURFACE = 2
	UI_BBOX = 4
	UI_SELECT = 8
end

isUIRenderType(rtype::UIRenderType, vtype::UIRenderType) = (rtype & vtype) == vtype

mutable struct UIObject{T<:RenderableUI} <: RenderableUI
	renderObj::T
	rType::UIRenderType
	wireFrame::Union{Nothing, RenderableUI}
	bbox::Union{Nothing, RenderableUI}
	axis::Union{Nothing, RenderableUI}
	select::Union{Nothing, RenderableUI}
end

isTextureDefined(wo::UIObject{T}) where T<:RenderableUI = isTextureDefined(T)
isTextureDefined(::Type{UIObject{T}}) where T<:RenderableUI = isTextureDefined(T)
isNormalDefined(wo::UIObject{T}) where T<:RenderableUI = isNormalDefined(T)
isNormalDefined(::Type{UIObject{T}}) where T<:RenderableUI = isNormalDefined(T)

function RenderableUICount(mesh::UIObject{T}) where T<:RenderableUI
	meshType = typeof(mesh)
	fieldTypes = fieldtypes(meshType)
	count((x)-> x>:RenderableUI, fieldTypes)
end

Base.setproperty!(wo::UIObject{T}, f::Symbol, v) where T<:RenderableUI = begin
	(f in fieldnames(wo |> typeof)) ?
		setfield!(wo, f, v) :
		setfield!(wo.renderObj, f, v)
	if isUIRenderType(wo.rType, UI_SURFACE) && wo.renderObj !== nothing
		setfield!(wo.renderObj, :uniformData, f==:uniformData ? v : computeUniformData(wo.renderObj))
		updateUniformBuffer(wo.renderObj)
	end
	if isUIRenderType(wo.rType, UI_BBOX) && wo.bbox !== nothing
		setfield!(wo.bbox, :uniformData, f==:uniformData ? v : computeUniformData(wo.bbox))
		updateUniformBuffer(wo.bbox)
	end
	if isUIRenderType(wo.rType, UI_SELECT) && wo.select !== nothing
		setfield!(wo.select, :uniformData, f==:uniformData ? v : computeUniformData(wo.select))
		updateUniformBuffer(wo.select)
	end
end

Base.getproperty(wo::UIObject{T}, f::Symbol) where T<:RenderableUI = begin
	(f in fieldnames(UIObject)) ?
		getfield(wo, f) :
		getfield(getfield(wo, :renderObj), f)
end

function prepareObject(gpuDevice, mesh::UIObject{T}) where T<:RenderableUI
	isUIRenderType(mesh.rType, UI_SURFACE) && mesh.renderObj !== nothing &&
		prepareObject(gpuDevice, mesh.renderObj)
	isUIRenderType(mesh.rType, UI_BBOX) && mesh.bbox !== nothing &&
		prepareObject(gpuDevice, mesh.bbox)
	isUIRenderType(mesh.rType, UI_SELECT) && mesh.select !== nothing &&
		prepareObject(gpuDevice, mesh.select)
end



function preparePipeline(gpuDevice, scene, mesh::UIObject{T}; binding=0) where T<:RenderableUI
	isUIRenderType(mesh.rType, UI_SURFACE) && mesh.renderObj !== nothing && 
		preparePipeline(gpuDevice, scene, mesh.renderObj; binding = binding)
	isUIRenderType(mesh.rType, UI_BBOX) && mesh.bbox !==nothing &&
		preparePipeline(gpuDevice, scene, mesh.bbox; binding = binding)
	isUIRenderType(mesh.rType, UI_SELECT) && mesh.select !== nothing &&
		preparePipeline(gpuDevice, scene, mesh.select; binding=binding)
end



function render(renderPass::WGPUCore.GPURenderPassEncoder, renderPassOptions, wo::UIObject, camId::Int)
	if isUIRenderType(wo.rType, UI_VISIBLE)
		isUIRenderType(wo.rType, UI_SURFACE) && wo.renderObj !== nothing &&
			render(renderPass, renderPassOptions, wo.renderObj, camId)
		isUIRenderType(wo.rType, UI_BBOX) && wo.bbox !== nothing &&
			render(renderPass, renderPassOptions, wo.bbox, camId)
		isUIRenderType(wo.rType, UI_SELECT) && wo.select !== nothing &&
			render(renderPass, renderPassOptions, wo.select, camId)
	end
end

