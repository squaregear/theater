defmodule Theater.Application do
  use Application

  require Logger

  def start(_type, _args) do
    Logger.info("Theater application starting")

    {persister, persister_opts}=Application.get_env(
      :theater,
      :persist,
      {Theater.Storage.MnesiaDisk, []}
    )

    children=[
      Supervisor.child_spec({persister, persister_opts},[]),
      Supervisor.child_spec({Theater.Launcher, persister},[]),
      Supervisor.child_spec({Theater.Stopper, nil},[]),
      Supervisor.child_spec({Theater, []},[]),
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Theater.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
