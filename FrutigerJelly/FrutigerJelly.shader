Shader "Custom/FrutigerAeroJelly_Shiny"
{
    Properties
    {
        _TopColor ("Top Color", Color) = (0.2,0.6,1,1)
        _BottomColor ("Bottom Color", Color) = (0.6,1,0.9,1)

        _RimColor ("Rim Color", Color) = (0.4,1,1,1)
        _RimPower ("Rim Power", Range(0.5,8)) = 4
        _RimStrength ("Rim Strength", Range(0,3)) = 1.2

        _HighlightStrength ("Top Highlight", Range(0,3)) = 1.2
        _HighlightSize ("Highlight Size", Range(0.1,2)) = 0.8

        _BumpMap ("Normal Map", 2D) = "bump" {}
        _Distortion ("Jelly Distortion", Range(0,0.5)) = 0.1

        _Shininess ("Shininess", Range(0.1,128)) = 32
        _SpecColor ("Specular Color", Color) = (1,1,1,1)

        _Alpha ("Transparency", Range(0,1)) = 0.6
    }

    SubShader
    {
        Tags{ "RenderType"="Transparent" "Queue"="Transparent" }

        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Back

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            sampler2D _BumpMap;

            float4 _TopColor;
            float4 _BottomColor;

            float4 _RimColor;
            float _RimPower;
            float _RimStrength;

            float _HighlightStrength;
            float _HighlightSize;

            float _Distortion;

            float _Shininess;
            float4 _SpecColor;

            float _Alpha;

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 normal : TEXCOORD0;
                float3 viewDir : TEXCOORD1;
                float2 uv : TEXCOORD2;
                float3 worldPos : TEXCOORD3;
            };

            v2f vert(appdata v)
            {
                v2f o;

                o.pos = UnityObjectToClipPos(v.vertex);

                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

                o.normal = UnityObjectToWorldNormal(v.normal);
                o.viewDir = normalize(_WorldSpaceCameraPos - worldPos);
                o.uv = v.uv;
                o.worldPos = worldPos;

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float3 normalTex = UnpackNormal(tex2D(_BumpMap, i.uv));
                float3 normal = normalize(i.normal + normalTex * _Distortion);

                // Fresnel Rim
                float rim = pow(1 - saturate(dot(normalize(i.viewDir), normal)), _RimPower);
                float3 rimLight = _RimColor.rgb * rim * _RimStrength;

                // Vertical Gradient
                float height = saturate(normal.y * 0.5 + 0.5);
                float3 gradient = lerp(_BottomColor.rgb, _TopColor.rgb, height);

                // Fake Top Highlight
                float highlight = pow(saturate(normal.y), 6) * _HighlightSize;
                float3 highlightCol = highlight * _HighlightStrength;

                // Shiny Specular (Blinn-Phong)
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                float3 H = normalize(lightDir + i.viewDir);
                float spec = pow(max(0, dot(normal, H)), _Shininess);

                // Modulate specular with Fresnel for jelly-like edges
                spec *= pow(1 - saturate(dot(normalize(i.viewDir), normal)), 0.5);
                float3 specular = _SpecColor.rgb * spec;

                // Final color
                float3 final = gradient + rimLight + highlightCol + specular;

                return float4(final, _Alpha);
            }
            ENDCG
        }
    }
}