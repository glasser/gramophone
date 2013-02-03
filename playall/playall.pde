#include "WaveHC.h"
#include "WaveUtil.h"

SdReader card;
FatVolume vol;
FatReader root;
WaveHC wave;

uint8_t dirLevel; // indent level for file/dir names    (for prettyprinting)
dir_t dirBuf;     // buffer for directory reads

#define REED 6

// An approximate number of times to run a loop such that, if we haven't
// transitioned in that many times, we are not spinning.
#define SPINNING_CYCLES 20000

#define error(msg) error_P(PSTR(msg))

void setup() {
  Serial.begin(9600);           // set up Serial library at 9600 bps

  PgmPrintln("\nWelcome to wave!");
  PgmPrint("Free RAM: ");
  Serial.println(FreeRam());

  /* pinMode(2, OUTPUT);  */
  /* pinMode(3, OUTPUT); */
  /* pinMode(4, OUTPUT); */
  /* pinMode(5, OUTPUT); */
  pinMode(REED, INPUT);
  
  //  if (!card.init(true)) { //play with 4 MHz spi if 8MHz isn't working for you
  if (!card.init()) {         //play with 8 MHz spi (default faster!)  
    error("Card init. failed!");  // Something went wrong, let's print out why
  }

  // enable optimize read - some cards may timeout. Disable if you're having problems
  card.partialBlockRead(true);
  // Now we will look for a FAT partition!
  uint8_t part;
  for (part = 0; part < 5; part++) {   // we have up to 5 slots to look in
    if (vol.init(card, part))
      break;                           // we found one, lets bail
  }
  if (part == 5) {                     // if we ended up not finding one  :(
    error("No valid FAT partition!");  // Something went wrong, lets print out why
  }
  // Lets tell the user about what we found
  putstring("Using partition ");
  Serial.print(part, DEC);
  putstring(", type is FAT");
  Serial.println(vol.fatType(),DEC);     // FAT16 or FAT32?
  // Try to open the root directory
  if (!root.openRoot(vol)) {
    error("Can't open root dir!");      // Something went wrong,
  }
  // Whew! We got past the tough parts.
  putstring_nl("Files found (* = fragmented):");

  // Print out all of the files in all the directories.
  root.ls(LS_R | LS_FLAG_FRAGMENTED);
}

uint8_t tracknum = 0;

void loop() {
  root.rewind();
  play(root);
}

/*
 * print error message and halt
 */
void error_P(const char *str)
{
  PgmPrint("Error: ");
  SerialPrint_P(str);
  sdErrorCheck();
  while(1);
}
/*
 * print error message and halt if SD I/O error, great for debugging!
 */
void sdErrorCheck(void)
{
  if (!card.errorCode()) return;
  PgmPrint("\r\nSD I/O error: ");
  Serial.print(card.errorCode(), HEX);
  PgmPrint(", ");
  Serial.println(card.errorData(), HEX);
  while(1);
}

/*
 * play recursively - possible stack overflow if subdirectories too nested
 */
void play(FatReader &dir)
{
  FatReader file;
  while (dir.readDir(dirBuf) > 0) {    // Read every file in the directory one at a time
  
    // Skip it if not a subdirectory and not a .WAV file
    if (!DIR_IS_SUBDIR(dirBuf)
         && strncmp_P((char *)&dirBuf.name[8], PSTR("WAV"), 3)) {
      continue;
    }

    Serial.println();            // clear out a new line
    
    for (uint8_t i = 0; i < dirLevel; i++) {
       Serial.print(' ');       // this is for prettyprinting, put spaces in front
    }
    if (!file.open(vol, dirBuf)) {        // open the file in the directory
      error("file.open failed");          // something went wrong
    }
    
    if (file.isDir()) {                   // check if we opened a new directory
      putstring("Subdir: ");
      printEntryName(dirBuf);
      dirLevel += 2;                      // add more spaces
      // play files in subdirectory
      play(file);                         // recursive!
      dirLevel -= 2;    
    }
    else {
      // Aha! we found a file that isnt a directory
      putstring("Playing ");
      printEntryName(dirBuf);              // print it out
      if (!wave.create(file)) {            // Figure out, is it a WAV proper?
        putstring(" Not a valid WAV");     // ok skip it
      } else {
        Serial.println();                  // Hooray it IS a WAV proper!
        playinteractive();
      }
    }
  }
}

int prev_magnet, cur_magnet, prev_spinning, cur_spinning, spin_count, period,
  prev_rate, cur_rate;

void playinteractive() {
  wave.play();
  wave.pause();

  prev_spinning = 0;
  prev_rate = 0;
  while (wave.isplaying) {
    prev_magnet = digitalRead(REED);
    // Assume it is not spinning.
    cur_spinning = 0;
    period = 0;
    for (spin_count = 1; spin_count < SPINNING_CYCLES; ++spin_count) {
      cur_magnet = digitalRead(REED);
      if (cur_spinning == 0) {
        if (prev_magnet != cur_magnet) {
          // Hey look, it is spinning.
          cur_spinning = 1;
          period = -spin_count;  // intermediate value
        }
      } else {
        if (prev_magnet == cur_magnet) {
          // It's back to the first value. We have our period!
          period += spin_count;
          break;
        }
      }
    }
    if (period < 0) {
      // This means we saw a change exactly once. Who knows what
      // that means. Let's not think very hard: back to the top of the loop.
      continue;
    }
    /* if (period > 0) { */
    /*   putstring("Period: "); */
    /*   Serial.println(period, DEC); */
    /* } */
    if (cur_spinning) {
      if (period < 3000) {
        cur_rate = 22050;
      } else {
        cur_rate = 18000;
      }
      /* if (period < 2100) { */
      /*   cur_rate = 22050;  // This is the "normal" rate of the song. */
      /* } else if (period < 2500) { */
      /*   cur_rate = 21000; */
      /* } else if (period < 3000) { */
      /*   cur_rate = 20000; */
      /* } else if (period < 4000) { */
      /*   cur_rate = 19000; */
      /* } else if (period < 6000) { */
      /*   cur_rate = 18000; */
      /* } else { */
      /*   cur_rate = 17000; */
      /* } */

      if (cur_rate != prev_rate) {
        putstring("Rate: ");
        Serial.println(cur_rate, DEC);
        wave.setSampleRate(cur_rate);
        prev_rate = cur_rate;
      }
    }

    if (cur_spinning != prev_spinning) {
      prev_spinning = cur_spinning;
      if (cur_spinning) {
        putstring("Resuming\n");
        wave.resume();
      } else {
        putstring("Pausing\n");
        wave.pause();
      }
    }
  }
  sdErrorCheck();
}
