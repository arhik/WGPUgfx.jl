
using WGPU
using GeometryBasics: Vec2, Vec4, Vec3, Mat4, Mat3, Mat2
using LinearAlgebra
using StaticArrays
using Rotations
using CoordinateTransformations


export defaultCamera, Camera, lookAtRightHanded, perspectiveMatrix, orthographicMatrix, 
	windowingTransform, translateCamera, openglToWGSL, translate, scaleTransform,
	getUniformBuffer, getUniformData


mutable struct Camera
	gpuDevice
	eye
	lookat
	up
	uniformData
	uniformBuffer
	scale
	fov
	aspectRatio
	nearPlane
	farPlane
	function Camera(gpuDevice, eye, lookat, up, scale, fov, aspectRatio, nearPlane, farPlane)
		scale = [1, 1, 1] .|> Float32
		camera = new(gpuDevice, eye, lookat, up, nothing, nothing, scale, fov, aspectRatio, nearPlane, farPlane)
		uniformData = computeUniformData(camera)
		(uniformBuffer, _) = WGPU.createBufferWithData(
			gpuDevice, 
			"uniformBuffer", 
			uniformData, 
			["Uniform", "CopyDst", "CopySrc"] # CopySrc during development only
		)
		setfield!(camera, :uniformData, uniformData)
		setfield!(camera, :uniformBuffer, uniformBuffer)
		return camera
	end
end


# TODO not used
function defaultUniformData(::Type{Camera}) 
	uniformData = ones(Float32, (4, 4)) |> Diagonal |> Matrix
	return uniformData
end


function computeUniformData(camera::Camera)
	viewMatrix = lookAtRightHanded(camera) ∘ scaleTransform(camera.scale .|> Float32)
	projectionMatrix = perspectiveMatrix(camera)
	viewProject = projectionMatrix ∘ viewMatrix
	uniformData = viewProject.linear
	return uniformData
end


function defaultCamera(gpuDevice)
	eye = [1.0, 1.0, 1.0] .|> Float32
	lookat = [0, 0, 0] .|> Float32
	up = [0, 1, 0] .|> Float32
	scale = [1, 1, 1] .|> Float32
	fov = pi/2 |> Float32
	aspectRatio = 1.0 |> Float32
	nearPlane = -1.0 |> Float32
	farPlane = -100.0 |> Float32
	return Camera(
		gpuDevice,
		eye,
		lookat,
		up,
		scale,
		fov,
		aspectRatio,
		nearPlane,
		farPlane
	)
end


Base.setproperty!(camera::Camera, f::Symbol, v) = begin
	setfield!(camera, f, v)
	setfield!(camera, :uniformData, f==:uniformData ? v : computeUniformData(camera))
	updateUniformBuffer(camera)
end

# TODO not working
Base.getproperty(camera::Camera, f::Symbol) = begin
	if f != :uniformBuffer
		return getfield(camera, f)
	else
		return readUniformBuffer(camera)
	end
end

xCoords(bb) = bb[1:2:end]
yCoords(bb) = bb[2:2:end]

lowerCoords(bb) = bb[1:2]
upperCoords(bb) = bb[3:4]


function translate(loc)
	(x, y, z) = loc
	return LinearMap(
		@SMatrix(
			[
				1 	0 	0 	x;
				0 	1 	0 	y;
				0 	0 	1 	z;
				0 	0 	0 	1;
			]
		) .|> Float32
	)
end


function scaleTransform(loc)
	(x, y, z) = loc
	return LinearMap(
		@SMatrix(
			[
				x 	0 	0 	0;
				0	y   0	0;
				0	0	z 	0;
				0	0	0	1;
			]
		) .|> Float32
	)

end


function translateCamera(camera::Camera)
	(x, y, z) = (camera.eye...,)
	return LinearMap(
		@SMatrix(
			[
				1 	0 	0 	x;
				0 	1 	0 	y;
				0 	0 	1 	z;
				0 	0 	0 	1;
			]
		) .|> Float32
	) |> inv
end


function computeScaleFromBB(bb1, bb2)
	scaleX = reduce(-, xCoords(bb2))./reduce(-, xCoords(bb1))
	scaleY = reduce(-, yCoords(bb2))./reduce(-, yCoords(bb1))
	scaleZ = 1
	return LinearMap(@SMatrix([scaleX 0 0 0; 0 scaleY 0 0; 0 0 scaleZ 0; 0 0 0 1]))
end


function windowingTransform(fromSize, toSize)
	trans1 = Translation([-lowerCoords(fromSize)..., 0, 0])
	trans2 = Translation([lowerCoords(toSize)..., 0, 0])
	scale = computeScaleFromBB(fromSize, toSize)
	return trans2 ∘ scale ∘ trans1 
end


"""
# Usage
bb1 = [20, 20, 400, 400]
bb2 = [40, 60, 500, 600]

transform = windowingTransform(bb1, bb2)

transform([upperCoords(bb1)..., 0, 0])

# Should write tests on it
"""


function lookAtRightHanded(camera::Camera)
	eye = camera.eye
	lookat = camera.lookat
	up = camera.up
	w = -(eye .- lookat) |> normalize
	u =	cross(up, w) |> normalize
	v = cross(w, u)
	m = Matrix{Float32}(I, (4, 4))
	m[1:3, 1:3] .= (cat([u, v, w]..., dims=2) |> adjoint .|> Float32 |> collect)
	return LinearMap(m) ∘ translateCamera(camera)
end


function perspectiveMatrix(camera::Camera)
	fov = camera.fov
	ar = camera.aspectRatio
	n = camera.nearPlane
	f = camera.farPlane
	t = n*tan(fov/2)
	b = -t
	r = ar*t
	l = -r
	return perspectiveMatrix(((n, f, l, r, t, b) .|> Float32)...)
end


function perspectiveMatrix(near::Float32, far::Float32, l::Float32, r::Float32, t::Float32, b::Float32)
	n = near
	f = far
	xS = -2*n/(r-l)
	yS = -2*n/(t-b)
	xR = -(r+l)/(r-l)
	yR = -(t+b)/(t-b)
	zR = -(f+n)/(n-f)
	oR = -2*f*n/(n-f)
	return LinearMap(
		@SMatrix(
			[
				xS		0		xR		0	;
				0		yS		yR		0	;
				0		0		zR		oR	;
				0		0		1		0	;
			]
		) .|> Float32
	)
end


function orthographicMatrix(w::Int, h::Int, near, far)
	yscale = 1/tan(fov/2)
	xscale = yscale/aspectRatio
	zn = near
	zf = far
	s = 1/(zn - zf)
	return LinearMap(
		@SMatrix(
			[
				2/w 	0      	0 		0;
				0		2/h		0		0;
				0	   	0		s		0;
				0		0		zn*s	1;
			]
		) .|> Float32
	)
end


function getUniformData(camera::Camera)
	return camera.uniformData
end


function updateUniformBuffer(camera::Camera)
	data = SMatrix{4, 4}(camera.uniformData[:])
	@info :UniformBuffer data
	WGPU.writeBuffer(
		camera.gpuDevice[].queue, 
		getfield(camera, :uniformBuffer),
		data,
	)
end

function readUniformBuffer(camera)
	data = WGPU.readBuffer(
		camera.gpuDevice,
		getfield(camera, :uniformBuffer),
		0,
		getfield(camera, :uniformBuffer).size
	)
	datareinterpret = reinterpret(Mat4{Float32}, data)[1]
	@info "Received Buffer" datareinterpret
end

function getUniformBuffer(camera)
	getfield(camera, uniformBuffer)
end


function getShaderCode(::Type{Camera})
	shaderSource = quote
		struct CameraUniform
			transform::Mat4{Float32}
		end
		@var Uniform 0 1 camera::@user CameraUniform
	end
	return shaderSource
end


function getVertexBufferLayout(::Type{Camera})
	WGPU.GPUVertexBufferLayout => []
end


function getBindingLayouts(::Type{Camera})
	bindingLayouts = [
		WGPU.WGPUBufferEntry => [
			:binding => 1,
			:visibility => ["Vertex", "Fragment"],
			:type => "Uniform"
		],
	]
	return bindingLayouts
end


function getBindings(::Type{Camera}, uniformBuffer)
	bindings = [
		WGPU.GPUBuffer => [
			:binding => 1,
			:buffer  => uniformBuffer,
			:offset  => 0,
			:size    => uniformBuffer.size
		],
	]
end


