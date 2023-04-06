#shader vertex
#version 330 core

layout(location = 0)in vec4 position;
layout(location = 1)in vec2 texCoord;
layout(location = 2)in vec4 vertexNormal;

out vec2 uv;

uniform mat4 u_mvp;
uniform float u_time;

void main()
{
	uv = texCoord;

	gl_Position = u_mvp * position;
}

#shader fragment
#version 330 core

layout(location = 0)out vec4 color;

in vec2 uv;

uniform vec4 u_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform sampler2D u_texture;
uniform float u_time;

void main()
{
	vec4 texColor = texture(u_texture, uv);
	color = texColor * u_color;
}