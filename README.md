# Snaker
A new and adjusted version of the classic Snake game, written in Elm and Phoenix.
Currently WIP because while multiplayer is working, it does't sync state properly.

![](https://raw.githubusercontent.com/JulianLeviston/snaker-elm/master/images/snaker-elm.png)

## Background

The idea should be familiar: you are a snake, and you want to eat randomly appearing apples. This makes you grow. Apples appear for a brief time, then reappear somewhere else.

You can try out the compiled code in `index.html`. All of the source is currently in `Main.elm`.

## Server

To start the Phoenix server:

  * Install dependencies with `mix deps.get`
  * Install Node.js dependencies with `cd assets && npm install`
  * Install Elm dependencies with `cd elm && elm package install` then `cd ../..`
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Development

The Elm app can be found in `/assets/elm`, and the Phoenix app is responsible for hosting and building the target Elm app using brunch.

## Future

So far, using the `Html` library, but will probably change soon for performance reasons. It feels like the `Time` subscription is not a good fit for a game like this.


Things that need to change:

* Fix the problem where the board is out of sync when new players join for various reasons:
  - make the first joining player become the "board sync client" (ie clients respond to a new message saying they're the BSC)
  - make it so the server has a clock it sends and is used by each client
  - switch the apple generation to a timed queue
  - make the server responsible for generating apples
  - each client will still be responsible for expiring and eating apples themselves
  - when a new client joins, the server will get the state of the board from the board sync client (ie the apples and snakes) and send it to the new client that just joined
  - when the board sync client closes connection, a message is sent to the first live client that it is now the board sync client

* Possibly using something that uses `requestAnimationFrame` instead of `setTimeout`.
* Possibly try re-building pieces in WebGL.
* Experiment with SVG instead of the `Html` library.
* "Levels" and other intresting features (more to come): implement new ideas for features to make it really fun.
* Remove the grid and make the styling nicer.
* A more interesting scoring system.
