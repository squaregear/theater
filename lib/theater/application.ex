defmodule Theater.Application do
  @moduledoc """
  This is the main application module for Theater.

  It reads some configuration and starts things that Theater needs.

  There is nothing to see here. Please disperse.
  """

  use Application

  require Logger

  @doc false
  def start(_type, _args) do
    Logger.info("Theater application starting")

    {persister, persister_opts}=Application.get_env(
      :theater,
      :persist,
      {Theater.Storage.MnesiaDisk, []}
    )

    is_server=not(Application.get_env(:theater, :client_only, false))
    theater_children=if is_server do
      [
        Supervisor.child_spec({persister, persister_opts},[]),
        Supervisor.child_spec({Theater.Launcher, persister},[]),
        Supervisor.child_spec({Theater.Stopper, nil},[]),
      ]
    else
      []
    end

    children=theater_children ++ [Supervisor.child_spec({Theater, is_server},[])]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Theater.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
