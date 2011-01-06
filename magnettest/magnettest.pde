#define REED 6

#define SAMPLES 50

#define error(msg) error_P(PSTR(msg))

void setup() {
  Serial.begin(9600);           // set up Serial library at 9600 bps
  Serial.println("Magnet Test!");
  pinMode(REED, INPUT);
}

uint32_t samples[SAMPLES];
uint32_t overflow[SAMPLES];
int values[SAMPLES];
uint16_t i;
int last, current;

void loop() {
  current = digitalRead(REED);
  for (i = 0; i < SAMPLES; ++i) {
    samples[i] = 0;
    overflow[i] = 0;
    values[i] = current;
    while (1) {
      last = current;
      current = digitalRead(REED);
      if (last == current) {
        ++samples[i];
        if (samples[i] == 10000000) {
          ++overflow[i];
        }
      } else {
        break;
      }
    }
  }
  for (i = 0; i < SAMPLES; ++i) {
    Serial.print(samples[i], DEC);
    Serial.print(", ");
    Serial.print(overflow[i], DEC);
    Serial.print(", value: ");
    Serial.println(values[i], DEC);
  }
  while (1) {}
}
