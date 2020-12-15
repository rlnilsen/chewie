# chewie

Generates a text file with data from each NES Tetris game played:
* Start date and time
* End date and time
* Start level
* End level
* Score
* Lines
* Number of each tetrimino

Requires playing Tetris through this [modified Nestopia libretro core](https://github.com/rlnilsen/libretro_nestopia_tetris).

## How to install

1. Install this [modified Nestopia libretro core](https://github.com/rlnilsen/libretro_nestopia_tetris).
2. Download zip file from [Releases](https://github.com/rlnilsen/chewie/releases) and copy the 'nestetris' folder to 'C:\\'.

## How to use

1. Start RetroArch and play NES Tetris using the 'Nestopia Tetris' core.
2. Run 'C:\\nestetris\\chewie\chewie.bat'.
3. Read the text file newly generated in 'C:\\nestetris\\'.
