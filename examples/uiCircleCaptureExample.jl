using Revise
using WGPUgfx
using WGPUCore
using GLFW
using GLFW: WindowShouldClose, PollEvents, DestroyWindow, WaitEvents
using LinearAlgebra
using Rotations
using StaticArrays
using WGPUNative
using Debugger

WGPUCore.SetLogLevel(WGPUCore.WGPULogLevel_Off)

scene = Scene();
renderer = getRenderer(scene);

circle = defaultUICircle(;nSectors=20, radius=0.2, color = [0.4, 0.3, 0.5, 0.2]);
circle2 = defaultUICircle(;nSectors=100, radius=0.25, color = [0.4, 0.3, 0.5, 0.6]);

addObject!(renderer, circle, scene.camera);
addObject!(renderer, circle2, scene.camera);
# quad.uniformData = Matrix{Float32}(I, (4, 4))

mouseState = defaultMouseState()

keyboardState= defaultKeyboardState()

attachEventSystem(renderer, mouseState, keyboardState)

function runApp(renderer)
	init(renderer)
    (y, x) = 2.0.*(mouseState.prevPosition./500.0 .- 0.5)
	object = mouseState.leftClick ? renderer.scene.objects[2] : renderer.scene.objects[1]
    object.uniformData = translate([x, -y, 0.0]).linear
	WGPUgfx.render(renderer.renderPass, renderer.renderPassOptions, object, renderer.scene.cameraId)
	deinit(renderer)
end

main = () -> begin
	try
		flag = false
		while !WindowShouldClose(scene.canvas.windowRef[])
			runApp(renderer)
			PollEvents()		
		end
	finally
		WGPUCore.destroyWindow(scene.canvas)
	end
end

if abspath(PROGRAM_FILE)==@__FILE__
	main()
else
	main()
end
