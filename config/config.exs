# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
# ecto:
# config :snaker,
#   ecto_repos: [Snaker.Repo]

# Configures the endpoint
config :snaker, SnakerWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "b7gIM26+Z3rBPByFm9tffYuKEjIz0B5ELdVVkJL6BvWkrhw1JZIeFyKvbEYVleg7",
  render_errors: [view: SnakerWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Snaker.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
