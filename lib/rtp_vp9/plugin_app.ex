defmodule Membrane.RTP.VP9.Plugin.App do
  @moduledoc false
  use Application
  alias Membrane.RTP.{VP9, PayloadFormat}

  @impl true
  def start(_type, _args) do
    PayloadFormat.register(%PayloadFormat{
      encoding_name: :VP9,
      payload_type: 98,
      depayloader: VP9.Depayloader,
      payloader: VP9.Payloader
    })

    PayloadFormat.register_payload_type_mapping(98, :VP9, 90_000)
    Supervisor.start_link([], strategy: :one_for_one, name: __MODULE__)
  end
end
