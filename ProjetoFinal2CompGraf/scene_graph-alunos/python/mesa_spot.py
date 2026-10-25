from __future__ import annotations

from typing import Any

import wgpu
from rendercanvas.glfw import RenderCanvas, loop

from camera3d import *
from spotlight import *
from shader import *
from pipeline import *
from phongmaterial import *
from transform import *
from node import *
from scene import *
from renderer import *
from cube import *
from sphere import *
from texture import *
from sampler import *
from textureset import *

canvas: RenderCanvas
device: wgpu.GPUDevice
context: Any
renderer: Renderer
camera: Camera3D
scene: Scene

viewer_pos = (3.5, 3.0, 5.0)


def initialize(device: wgpu.GPUDevice, target_format: str) -> None:
    global camera, scene


    camera = Camera3D(*viewer_pos)
    camera.set_center(0.0, 1.0, 0.0)  
    arcball = camera.create_arcball()
    arcball.attach(canvas)


    light = SpotLight(0.15, 4.2, 0.9,        
                      -0.05, -2.4, -0.95,    
                      angle=27.0, exponent=14.0, space="world")


    wood = PhongMaterial(0.60, 0.38, 0.18)
    orange = PhongMaterial(0.95, 0.70, 0.15)
    green = PhongMaterial(0.15, 0.75, 0.40)
    red = PhongMaterial(0.90, 0.10, 0.20)
    white = PhongMaterial(1.0, 1.0, 1.0)
    shader = Shader(device, "../shaders/ilum_frag/spot_rugosidade.wgsl", light=light, space="world")
    # mesma ordem de slots do Cube e da Sphere: coord, normal, tangent, texcoord
    shader.set_vertex_buffers([
        {"array_stride": 3 * 4, "step_mode": "vertex",
         "attributes": [{"format": "float32x3", "offset": 0, "var_name": "coord"}]},
        {"array_stride": 3 * 4, "step_mode": "vertex",
         "attributes": [{"format": "float32x3", "offset": 0, "var_name": "normal"}]},
        {"array_stride": 3 * 4, "step_mode": "vertex",
         "attributes": [{"format": "float32x3", "offset": 0, "var_name": "tangent"}]},
        {"array_stride": 2 * 4, "step_mode": "vertex",
         "attributes": [{"format": "float32x2", "offset": 0, "var_name": "texcoord"}]},
    ])
    pipeline = Pipeline(shader, target_format, primitive={"cull_mode": "back"})
    shader.add_material(wood)
    shader.add_material(orange)
    shader.add_material(green)
    shader.add_material(red)
    shader.add_material(white)

    # texturas neutras: decal branco nao altera a cor do material e o mapa
    # (0.5,0.5,1.0) decodifica para n = (0,0,1), ou seja, superficie lisa
    decal_neutro = Texture(device, "decal_texture", None, texel=(1.0, 1.0, 1.0))
    normal_neutro = Texture(device, "normal_texture", None, texel=(0.5, 0.5, 1.0), format="rgba8unorm")
    tex_sampler = Sampler(device, "tex_sampler")
    neutro = TextureSet([decal_neutro, normal_neutro, tex_sampler])
    shader.add_texture_set(neutro)

    # esferas: mesmo decal neutro, mas com o mapa de normais da bola de golfe
    # (rgba8unorm, pois guarda vetores e nao cor)
    normal_golfe = Texture(device, "normal_texture", "../images/golfball.png", format="rgba8unorm")
    golfe = TextureSet([decal_neutro, normal_golfe, tex_sampler])
    shader.add_texture_set(golfe)
    decal_terra = Texture(device, "decal_texture", "../images/earth.jpg")
    decal_relogio = Texture(device, "decal_texture", "../images/stopwatch.jpg")
    terra = TextureSet([decal_terra, normal_golfe, tex_sampler])
    relogio = TextureSet([decal_relogio, normal_neutro, tex_sampler])
    shader.add_texture_set(terra)
    shader.add_texture_set(relogio)


    cube = Cube(device)
    sphere = Sphere(device)

    leg_height = 1.5
    leg_thickness = 0.15
    table_width = 3.0   
    table_depth = 2.0   
    top_thickness = 0.2
    table_surface_y = leg_height + top_thickness

    half_w = table_width / 2
    half_d = table_depth / 2
    inset = 0.25

    def leg_transform(lx: float, lz: float) -> Transform:
        trf = Transform()
        trf.translate(lx, 0.0, lz)
        trf.scale(leg_thickness, leg_height, leg_thickness)
        return trf

    trf_top = Transform()
    trf_top.translate(0.0, leg_height, 0.0)
    trf_top.scale(table_width, top_thickness, table_depth)
    trf_leg_fl = leg_transform(-(half_w - inset), -(half_d - inset))
    trf_leg_fr = leg_transform(half_w - inset, -(half_d - inset))
    trf_leg_bl = leg_transform(-(half_w - inset), half_d - inset)
    trf_leg_br = leg_transform(half_w - inset, half_d - inset)


    box_x, box_z = -0.4, 0.1
    box_w, box_h, box_d = 0.7, 0.4, 0.5
    box_top_y = table_surface_y + box_h

    trf_box = Transform()
    trf_box.translate(box_x, table_surface_y, box_z)
    trf_box.scale(box_w, box_h, box_d)

    def sphere_transform(sx: float, sz: float, radius: float, base_y: float) -> Transform:
        trf = Transform()
        trf.translate(sx, base_y + radius, sz)
        trf.scale(radius, radius, radius)
        return trf


    trf_sphere_green = sphere_transform(box_x - 0.1, box_z + 0.15, 0.25, box_top_y)
    trf_sphere_red = sphere_transform(0.9, -0.3, 0.58, table_surface_y)

    root = Node(pipeline, nodes=[
        Node(None, trf_top, [wood, neutro], [cube]),
        Node(None, trf_leg_fl, [wood, neutro], [cube]),
        Node(None, trf_leg_fr, [wood, neutro], [cube]),
        Node(None, trf_leg_bl, [wood, neutro], [cube]),
        Node(None, trf_leg_br, [wood, neutro], [cube]),
        Node(None, trf_box, [orange, relogio], [cube]),
        Node(None, trf_sphere_green, [white, terra], [sphere]),
        Node(None, trf_sphere_red, [red, golfe], [sphere]),
    ])
    scene = Scene(root)


def draw() -> None:
    target_texture = context.get_current_texture()
    renderer.render(target_texture, scene, camera)


def on_key(event: Any) -> None:
    if event["key"] == "q":
        canvas.close()


def main() -> None:
    global canvas, device, context, renderer

    canvas = RenderCanvas(
        size=(800, 600),
        title="Mesa spot com rugosidade",
        update_mode="continuous",
        max_fps=60,
    )
    adapter = wgpu.gpu.request_adapter_sync()
    device = adapter.request_device_sync()
    context = canvas.get_context("wgpu")
    target_format = context.get_preferred_format(device.adapter)
    context.configure(device=device, format=target_format)

    renderer = Renderer(device, depth_test=True, clear_value=(0.9, 0.9, 0.9, 1.0))

    initialize(device, target_format)

    canvas.add_event_handler(on_key, "key_down")
    canvas.request_draw(draw)
    loop.run()


if __name__ == "__main__":
    main()