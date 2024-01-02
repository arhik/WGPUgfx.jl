using Revise
using Tracy
using WGPUgfx
using WGPUCore
using WGPUCanvas
using GLFW
using GLFW: WindowShouldClose, PollEvents, DestroyWindow
using LinearAlgebra
using Rotations
using StaticArrays
using WGPUNative
using Images

WGPUCore.SetLogLevel(WGPUCore.WGPULogLevel_Debug)

scene = Scene()
renderer = getRenderer(scene)

# pc = defaultGSplat(joinpath(pkgdir(WGPUgfx), "assets", "bonsai", "bonsai_30000.ply"))
pc = defaultGSplat(joinpath("C:\\", "Users", "arhik", "Downloads", "bonsai_30000.compressed.ply"))

addObject!(renderer, pc)

attachEventSystem(renderer)

function runApp(renderer)
    init(renderer)
    render(renderer)
    deinit(renderer)
end

mainApp = () -> begin
	try
		count = 0
		camera1 = scene.cameraSystem[1]
		while !WindowShouldClose(scene.canvas.windowRef[])
			# rot = RotXY(0.01, 0.02)
			# mat = MMatrix{4, 4, Float32}(I)
			# mat[1:3, 1:3] = rot
			# camera1.transform = camera1.transform*mat
			# theta = time()
			# pc.uniformData = translate((				
			# 	1.0*(sin(theta)), 
			# 	1.0*(cos(theta)), 
			# 	0, 
			# 	1
			# )).linear
			runApp(renderer)
			PollEvents()
		end
	finally
		WGPUCore.destroyWindow(scene.canvas)
	end
end

if abspath(PROGRAM_FILE)==@__FILE__
	mainApp()
else
	mainApp()
end


