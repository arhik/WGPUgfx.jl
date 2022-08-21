module ShaderMod

using WGPU_jll
using WGPU

include("macros.jl")
include("primitives.jl")

using .MacroMod
using .MacroMod: wgslCode

using .PrimitivesMod

export createShaderObj, defaultCamera, defaultCube, Cube, Camera, getShaderCode,
		getVertexBuffer, defaultUniformData, getUniformBuffer, getIndexBuffer,
		getBindingLayouts, getBindings, getVertexBufferLayout, defaultPlane, Plane,
		defaultTriangle3D, Triangle3D, perspectiveMatrix, orthographicMatrix, lookAtRightHanded,
		windowingTransform, translateCamera, openglToWGSL, defaultCircle, Circle, translate,
		scaleTransform

struct ShaderObj
	src
	internal
	descriptor
end


function createShaderObj(gpuDevice, shaderSource)
	shaderSource = shaderSource |> wgslCode 
	shaderBytes  = shaderSource |> Vector{UInt8}

	descriptor = WGPU.loadWGSL(shaderBytes) |> first

	ShaderObj(
		shaderSource,
		WGPU.createShaderModule(
			gpuDevice,
			"shaderCode",
			descriptor,
			nothing,
			nothing
		) |> Ref,
		descriptor
	)

end

end