# Snaker
A new and adjusted version of the classic Snake game, written in Elm and Phoenix

![](https://raw.githubusercontent.com/JulianLeviston/snaker-elm/master/images/snaker-elm.png)

## Background

The idea should be familiar: you are a snake, and you want to eat randomly appearing apples. This makes you grow. Apples appear for a brief time, then reappear somewhere else.

You can try out the compiled code in `index.html`. All of the source is currently in `Main.elm`.

## Server

To start the Phoenix server:

  * Install dependencies with `mix deps.get`
  * Install Node.js dependencies with `cd assets && npm install`
  * Start Phoenix endpoint with `mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Development

The Elm app can be found in `/assets/elm`, and the Phoenix app is responsible for hosting and building the target Elm app using brunch.

## Future

So far, using the `Html` library, but will probably change soon for performance reasons. It feels like the `Time` subscription is not a good fit for a game like this.


Things I'd like to change:

* WebSockets with Phoenix
* Using something that uses `requestAnimationFrame` instead of `setTimeout`
* Possibly try re-building pieces in WebGL
* Experiment with SVG instead of the `Html` library
* Network Multiplayer (To test out writing some Elixir).
* "Levels" (more to come).
* A more consistent timing system for the apples to appear.
* Remove the grid and make the styling nicer.
* A more interesting scoring system.
