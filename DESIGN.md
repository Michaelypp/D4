# Design

Fill this in as you go. Your partner, future teammates, and the review bot read it
to learn where your project is headed. Replace each _italic prompt_.

## Target

The player steers a robot chef and its conveyor belt through a 20 × 20 sushi restaurant, including the walls. Each ingredient collected adds a point and a belt segment, making the restaurant harder to navigate. The planned delivery system lets the robot carry ingredients to customers waiting beside walls.

## Menu choices

Two items from two different groups (see the D4 guide's "The menu" tab).

| Item | Group | Done when (in your words) |
| --- | --- | --- |
| Customer orders and sushi delivery | Systems/Propose your own | Tests show that entering a customer’s wall-adjacent floor cell with too few ingredients leaves the order open, an exact match consumes the cargo, awards bonus points and removes one belt segment per ingredient, a wrong recipe with the right count empties the cargo and adds empty belt segments, and a tick-based timeout adds empty segments and replaces the customer. |
| Text-file levels | Language | Three kitchen layouts load from text files with a shared legend for floors, walls, tables, counters and the robot start, and tests verify that every layout has room for the starting belt. |

The game discovers `.txt` layouts in `levels/` in filename order. Use `.` for floor, `#` for walls, `T` for tables, `C` for counters, and one `S` for the robot’s starting head. Keep rows the same width, surround the map with walls, and leave three open cells to the left of `S` and one open cell to the right. Press Tab before starting or after a run to switch restaurants.

## Words we use

Each word your project uses, what it means, and where it lives in code. A few are
already here from the starter; keep them accurate as you change things.

| Word | Meaning | In code |
| --- | --- | --- |
| cell | one square of the grid | `Vector2i` |
| session | one run at the game, from the first tick until it ends; owns the board and the dragon | `Session` in `core/session.gd` |
| tick | one step of the rules; the dragon moves one cell | `Session.tick()`, `Dragon.tick()` |
| tile kind | what a cell is made of, such as `floor` or `wall` | `Board.TILES`, `TILES` in `tools/build_art.py` |
| piece | one model in the kit: head, straight, turn, tail | `Kit.Piece`, `PIECES` in `tools/build_art.py` |
| _word_ | _meaning_ | _where_ |

## Where things live

_Where do the rules live, where does drawing happen, and how does an event get from
one to the other in your project?_

## Adding a tile kind

_The steps a teammate would follow, naming your actual files._

## Patterns, and what they bought us

_Each pattern you used on purpose, where it is, and what it made easier (or harder).
Where a SOLID principle explains why it helped (for example, open/closed: a new tile
kind or powerup is added, not edited in), say which one._

## One idea we carried over

_Pick one idea you used earlier this quarter in TypeScript (for example a Command queue,
a core kept apart from the framework, data-driven content, or a boundary gate) and
describe its transfer at three levels:_

- _**The problem:** what goes wrong without it, in any engine or language._
- _**The practice:** what we do about it, the same here as in our TypeScript Demos._
- _**The mechanism:** how Godot, GDScript, or Blender does it, and what changed from
  TypeScript (what got easier, what got harder, what we had to give up)._

## Sources we relied on

Claims about how Godot or Blender behaves, checked against the documentation for the
versions we run (Godot 4.7, Blender 5.2). Add a row when a decision depends on one.

| Claim | Source (link) | How we checked it |
| --- | --- | --- |
| _what the tool does_ | _manual page or source file_ | _what we ran or looked at_ |
