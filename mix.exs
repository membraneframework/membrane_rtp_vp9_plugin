defmodule Membrane.Template.Mixfile do
  use Mix.Project

  @version "0.1.0"
  @github_url "https://github.com/membraneframework/membrane_rtp_vp9_plugin"

  def project do
    [
      app: :membrane_template_plugin,
      version: @version,
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # hex
      description: "Membrane Multimedia Framework (RTP VP9)",
      package: package(),

      # docs
      name: "Membrane: RTP VP9",
      source_url: @github_url,
      homepage_url: "https://membraneframework.org",
      docs: docs()
    ]
  end

  def application do
    [
      extra_applications: [],
      mod: {Membrane.RTP.VP9.Plugin.App, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]

  defp deps do
    [
      {:membrane_core, "~> 0.6.0", override: true},
      {:ex_doc, "~> 0.22", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0", only: :dev, runtime: false},
      {:credo, "~> 1.4", only: :dev, runtime: false},
      {:membrane_rtp_format, "~> 0.3.0"},
      {:membrane_vp9_format, github: "membraneframework/membrane_vp9_format"},
      {:membrane_element_pcap, github: "membraneframework/membrane-element-pcap", only: :test},
      {:membrane_rtp_plugin,
       github: "membraneframework/membrane_rtp_plugin", branch: :sending, only: :test},
      {:membrane_file_plugin, "~> 0.5.0", only: :test},
      {:membrane_remote_stream_format, "~> 0.1.0"},
      {:membrane_caps_rtp, "~> 0.1.0"}
    ]
  end

  defp package do
    [
      maintainers: ["Membrane Team"],
      licenses: ["Apache 2.0"],
      links: %{
        "GitHub" => @github_url,
        "Membrane Framework Homepage" => "https://membraneframework.org"
      }
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "LICENSE"],
      source_ref: "v#{@version}",
      nest_modules_by_prefix: [Membrane.RTP.VP9]
    ]
  end
end
