Shader "New Chromantics/ScanlineFilter"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		MatchColour("MatchColour", COLOR ) = (0,0,0)
		HslTolerance("HslTolerance", Range(0,1) ) = 0.20
		SampleSteps("SampleSteps", Range(1,40) ) = 10
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100
		Cull Off

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#define MAX_STEPS	20

			#include "UnityCG.cginc"
			#include "../PopUnityCommon/PopCommon.cginc"


			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float4 _MainTex_TexelSize;
			int SampleSteps;
			float HslTolerance;
			float3 MatchColour;

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
				o.uv = v.uv;
				return o;
			}


float GetHslHslDifference(float3 a,float3 b)
{
	float ha = a.x;
	float hb = b.x;
	float sa = a.y;
	float sb = b.y;
	float la = a.z;
	float lb = b.z;
	
	float sdiff = abs( sa - sb );
	float ldiff = abs( la - lb );
	
	//	hue wraps, so difference needs to be calculated differently
	//	convert -1..1 to -0.5...0.5
	float hdiff = ha - hb;
	hdiff = ( hdiff > 0.5f ) ? hdiff - 1.f : hdiff;
	hdiff = ( hdiff < -0.5f ) ? hdiff + 1.f : hdiff;
	hdiff = abs( hdiff );
	
	//	the higher the weight, the MORE difference it detects
	float hweight = 1.f;
	float sweight = 1.f;
	float lweight = 2.f;
#define NEAR_WHITE	0.8f
#define NEAR_BLACK	0.3f
#define NEAR_GREY	0.3f
	
	//	if a or b is too light, tone down the influence of hue and saturation
	{
		float l = max(la,lb);
		float Change = ( max(la,lb) > NEAR_WHITE ) ? ((l - NEAR_WHITE) / ( 1.f - NEAR_WHITE )) : 0.f;
		hweight *= 1.f - Change;
		sweight *= 1.f - Change;
	}
	//	else
	{
		float l = min(la,lb);
		float Change = ( min(la,lb) < NEAR_BLACK ) ? l / NEAR_BLACK : 1.f;
		hweight *= Change;
		sweight *= Change;
	}
	
	//	if a or b is undersaturated, we reduce weight of hue
	
	{
		float s = min(sa,sb);
		hweight *= ( min(sa,sb) < NEAR_GREY ) ? s / NEAR_GREY : 1.f;
	}
	
	
	//	normalise weights to 1.f
	float Weight = hweight + sweight + lweight;
	hweight /= Weight;
	sweight /= Weight;
	lweight /= Weight;
	
	float Diff = 0.f;
	Diff += hdiff * hweight;
	Diff += sdiff * sweight;
	Diff += ldiff * lweight;
	
	//	nonsense HSL values result in nonsense diff, so limit output
	Diff = min( Diff, 1.f );
	Diff = max( Diff, 0.f );
	return Diff;
}


			float3 GetHslSample(int2 Pos)
			{
				float2 uv = Pos*_MainTex_TexelSize.xy;
				float3 rgb = tex2D(_MainTex, uv ).xyz;
				return RgbToHsl(rgb);
			}

			float GetDiff(int2 Pos,float3 BaseHsl)
			{
				float3 MatchHsl = GetHslSample( Pos );
				return GetHslHslDifference( BaseHsl, MatchHsl );
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				int2 BasePos = i.uv * _MainTex_TexelSize.zw;

				float3 BaseHsl = GetHslSample( BasePos );
				//float3 BaseHsl = RgbToHsl( MatchColour );

				int StepsRight = 0;
				for ( int x=1;	x<min(SampleSteps,MAX_STEPS);	x++ )
				{
					float Diff = GetDiff( BasePos+int2(x,0), BaseHsl );
					if ( Diff < HslTolerance )
						StepsRight++;
					else
						break;
					
				}

				int StepsLeft = 0;
				for ( int x=1;	x<min(SampleSteps,MAX_STEPS);	x++ )
				{
					float Diff = GetDiff( BasePos+int2(-x,0), BaseHsl );
					if ( Diff < HslTolerance )
						StepsLeft++;
					else
						break;
					
				}

				int StepsUp = 0;
				for ( int x=1;	x<min(SampleSteps,MAX_STEPS);	x++ )
				{
					float Diff = GetDiff( BasePos+int2(0,-x), BaseHsl );
					if ( Diff < HslTolerance )
						StepsUp++;
					else
						break;
					
				}



				//return float4(MaxDiff,BaseHsl.z,BaseHsl.z,1);

				float SteppedLeft = StepsLeft / (float)SampleSteps;
				float SteppedRight = StepsRight / (float)SampleSteps;
				float SteppedUp = StepsUp / (float)SampleSteps;

				return float4( SteppedLeft,SteppedRight,SteppedUp, 1 ); 
			}
			ENDCG
		}
	}
}
