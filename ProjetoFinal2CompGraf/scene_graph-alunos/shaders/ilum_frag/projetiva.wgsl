struct Matrix {
  vertex: mat4x4<f32>,
  normal: mat4x4<f32>,
}
@group(1) @binding(0) var<storage, read> matrix: array<Matrix>;

struct Global {
  projection: mat4x4<f32>,   // espaco de iluminacao -> NDC
  light_ambient: vec3<f32>,
  light_diffuse: vec3<f32>,
  light_specular: vec3<f32>,
  light_position: vec4<f32>,
  camera_position: vec4<f32>,  // posição da câmera no espaço de iluminação
  projector_matrix: mat4x4<f32>,
}
@group(0) @binding(0) var<uniform> global: Global;

struct Material {
  base_color: vec3<f32>,
  opacity: f32,

  specular_color: vec3<f32>,
  shininess: f32,
}
@group(2) @binding(0) var<uniform> material: Material;

@group(3) @binding(0) var slide_texture: texture_2d<f32>;
@group(3) @binding(1) var slide_sampler: sampler;
@group(3) @binding(2) var decal_texture: texture_2d<f32>;
@group(3) @binding(3) var decal_sampler: sampler;

struct VertexOutput {
  @builtin(position) clip_position: vec4<f32>,
  @location(0) normal: vec3<f32>,
  @location(1) position: vec3<f32>,
  @location(2) projcoord: vec4<f32>,
  @location(3) texcoord: vec2<f32>,
}

@vertex
fn vs_main (@builtin(instance_index) instance_index: u32, @location(0) coord: vec3<f32>, @location(1) normal: vec3<f32>, @location(2) tangent: vec3<f32>, @location(3) texcoord: vec2<f32>) -> VertexOutput {
  let m = matrix[instance_index];
  var out: VertexOutput;
  let p = m.vertex * vec4<f32>(coord, 1.0);
  out.position = p.xyz;
  out.projcoord = global.projector_matrix * p;
  out.normal = (m.normal * vec4<f32>(normal, 0.0)).xyz;
  out.clip_position = global.projection * p;
  out.texcoord = texcoord;
  return out;
}

@fragment
fn fs_main (in: VertexOutput) -> @location(0) vec4<f32> {
  let normal = normalize(in.normal);
  let light = normalize(global.light_position.xyz - in.position);
  let view = normalize(global.camera_position.xyz - in.position);

  let proj = in.projcoord.xyz / in.projcoord.w;
  let slide = textureSample(slide_texture, slide_sampler, proj.xy).rgb;
  let lcolor = select(vec3<f32>(0.0), slide, proj.z >= 0.0 && proj.z <= 1.0);
  let decal = textureSample(decal_texture, decal_sampler, in.texcoord).rgb;
  let base = material.base_color * decal;
  var color = base * global.light_ambient;
  let ndotl = dot(normal, light);
  if (ndotl > 0.0) {
    color += base * global.light_diffuse * ndotl * lcolor;
    let refl = normalize(reflect(-light, normal));
    color += material.specular_color * global.light_specular * pow(max(0.0, dot(refl, view)), material.shininess) * lcolor;
  }
  return vec4<f32>(color, 1.0);
}
