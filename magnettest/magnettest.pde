#define REED 6

// An approximate number of times to run a loop such that, if we haven't
// transitioned in that many times, we are not spinning.
#define SPINNING_CYCLES 10000

#define error(msg) error_P(PSTR(msg))

int prev_magnet, cur_magnet, prev_spinning, cur_spinning, i;

void setup() {
  Serial.begin(9600);           // set up Serial library at 9600 bps
  Serial.println("Magnet Test!");
  pinMode(REED, INPUT);
  prev_spinning = 0;
}

void loop() {
  prev_magnet = digitalRead(REED);
  // Assume it is not spinning.
  cur_spinning = 0;
  for (i = 0; i < SPINNING_CYCLES; ++i) {
    cur_magnet = digitalRead(REED);
    if (prev_magnet != cur_magnet) {
      // Hey look, it is spinning.
      cur_spinning = 1;
      break;
    }
  }
  if (cur_spinning != prev_spinning) {
    prev_spinning = cur_spinning;
    Serial.println(cur_spinning ? "spinning!" : "stopped!");
  }
}
