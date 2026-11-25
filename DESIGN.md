# Design

Fill this in as you go. Your partner, future teammates, and the review bot read it
to learn where your project is headed. Replace each _italic prompt_.

## Target

The moving creature in the game is a robot chef that steers a conveyer built through a sushi restaurant/bar. The robot chef eats sushi ingredients like rice, salmon, nori, cucumber, etc. Each ingredient adds a segment to the belt if combinations are made. Playing should feel fun and immersive and increasingly difficult to navigate around the restaurant space. The grid is 20 × 20, including the walls.

## Menu choices

Two items from two different groups (see the D4 guide's "The menu" tab).

| Item | Group | Done when (in your words) |
| --- | --- | --- |
| Item	Group	Done when
Customer orders and sushi delivery | Systems/Propose your own | The game shows one active customer order and its recipe. Collecting the required ingredients lets the chef deliver at a marked pickup counter. A successful delivery uses those ingredients, awards bonus points, and removes one belt segment per ingredient used. Tests cover a successful delivery and an attempt with missing ingredients. |
| Text-file levels | Language | Three kitchen layouts load from text files using a legend for floor, tables, counters, and the delivery spot. Adding a layout requires no code changes. Tests load all three and check that each starting area is clear. |

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
