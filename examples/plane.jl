
using WGPUgfx
using WGPUCore
using GLFW
using GLFW: WindowShouldClose, PollEvents, DestroyWindow
using LinearAlgebra
using Rotations
using StaticArrays

WGPUCore.SetLogLevel(WGPUCore.WGPULogLevel_Off)

canvas = WGPUCore.defaultInit(WGPUCore.WGPUCanvas);
gpuDevice = WGPUCore.getDefaultDevice();

scene = Scene(canvas, [], repeat([nothing], 9)...)
camera = defaultCamera(gpuDevice)
push!(scene.objects, camera)
plane = defaultPlane()
push!(scene.objects, plane)

(renderPipeline, _) = setup(scene, gpuDevice);

main = () -> begin
	try
		while !WindowShouldClose(canvas.windowRef[])
			camera = scene.camera
			rotxy = RotXY(pi/3, time())
			camera.scale = [1, 1, 1] .|> Float32
			camera.eye = rotxy*([0.0, 0.0, -4.0] .|> Float32)
			runApp(scene, gpuDevice, renderPipeline)
			PollEvents()
		end
	finally
		WGPUCore.destroyWindow(canvas)
	end
end

task = Task(main)

schedule(task)
