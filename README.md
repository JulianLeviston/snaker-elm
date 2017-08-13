# snaker-elm
A touch and ready snake clone in elm

So far, using the `Http` library, but will probably change soon for performance reasons. It feels like the `Time` subscription is not a good fit for a game like this.

The idea should be familiar: you are a snake, and you want to eat randomly appearing apples. This makes you grow. Apples appear for a brief time, then reappear somewhere else.

You can try out the compiled code in `index.html`. All of the source is currently in `Main.elm`.

Things I'd like to add:

* Experiment with and pick better data structures for the grid.
* Network Multiplayer (To test out writing some Elixir).
* "Levels" (more to come).
* A more consistent timing system for the apples to appear.
* Remove the grid and make the styling nicer.
* A more interesting scoring system.
