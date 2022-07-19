const float WindSpeed_Calm = 3.4;
const float WindSpeed_Storm = 25.5;

float GetWindSpeed() {
	return mix(WindSpeed_Calm, WindSpeed_Storm, rainStrength);
}
