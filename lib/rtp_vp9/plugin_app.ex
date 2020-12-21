defmodule Membrane.RTP.VP9.Plugin.App do
  @moduledoc false
  use Application
  alias Membrane.RTP.{VP9, PayloadFormat}

  @spec start(any, any) :: none
  def start(_type, _args) do
    PayloadFormat.register(%PayloadFormat{
      encoding_name: :VP9,
      payload_type: 96,
      payloader: VP9.Depayloader,
      depayloader: VP9.Depayloader
    })

    PayloadFormat.register_payload_type_mapping(96, :VP9, 90_000)
    Supervisor.start_link([], strategy: :one_for_one, name: __MODULE__)
  end
end
