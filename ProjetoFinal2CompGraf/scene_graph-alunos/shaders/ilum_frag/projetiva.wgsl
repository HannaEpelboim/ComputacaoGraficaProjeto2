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
}
@group(0) @binding(0) var<uniform> global: Global;

struct Material {
  base_color: vec3<f32>,
  opacity: f32,

  specular_color: vec3<f32>,
  shininess: f32,
}
@group(2) @binding(0) var<uniform> material: Material;

struct VertexOutput {
  @builtin(position) clip_position: vec4<f32>,
  @location(0) normal: vec3<f32>,
  @location(1) position: vec3<f32>,   
}

@vertex
fn vs_main (@builtin(instance_index) instance_index: u32, @location(0) coord: vec3<f32>, @location(1) normal: vec3<f32>) -> VertexOutput {
  let m = matrix[instance_index];
  var out: VertexOutput;
  let p = m.vertex * vec4<f32>(coord, 1.0);
  out.position = p.xyz;
  out.normal = (m.normal * vec4<f32>(normal, 0.0)).xyz;
  out.clip_position = global.projection * p;
  return out;
}

@fragment
fn fs_main (in: VertexOutput) -> @location(0) vec4<f32> {
  let normal = normalize(in.normal);
  let light = normalize(global.light_position.xyz - in.position);
  let view = normalize(global.camera_position.xyz - in.position);

  
  var color = material.base_color * global.light_ambient;
  let ndotl = dot(normal, light);
  if (ndotl > 0.0) {
    color += material.base_color * global.light_diffuse * ndotl;
    let refl = normalize(reflect(-light, normal));
    color += material.specular_color * global.light_specular * pow(max(0.0, dot(refl, view)), material.shininess);
  }
  return vec4<f32>(color, 1.0);
}
