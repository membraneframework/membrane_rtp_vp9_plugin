defmodule Membrane.RTP.VP9.DepayloaderWithSessionBinTest do
  use ExUnit.Case

  import Membrane.Testing.Assertions

  alias Membrane.Testing
  alias Membrane.RTP
  alias Membrane.RTP.VP9.IVFWritter

  @ivf_result_file "./test/results/result.ivf"

  @rtp_input %{
    pcap: "test/fixtures/vp9_sample.pcap",
    video: %{ssrc: 119_745_458, frames_n: 300}
  }

  @fmt_mapping %{96 => {:VP9, 90_000}}

  defmodule TestPipeline do
    use Membrane.Pipeline

    @impl true
    def handle_init(options) do
      spec = %ParentSpec{
        children: [
          pcap: %Membrane.Element.Pcap.Source{path: options.input.pcap},
          rtp: %RTP.SessionBin{
            fmt_mapping: options.fmt_mapping
          }
        ],
        links: [
          link(:pcap)
          |> via_in(:rtp_input)
          |> to(:rtp)
        ]
      }

      {{:ok, spec: spec}, %{:result_file => options.result_file}}
    end

    @impl true
    def handle_notification({:new_rtp_stream, ssrc, _pt}, :rtp, _ctx, %{result_file: result_file} = state) do
      spec = %ParentSpec{
        children: [
          {{:file_sink, ssrc}, %Membrane.File.Sink{location: result_file}},
          {:ivf_writter, %IVFWritter{width: 1080, height: 720}}
        ],
        links: [
          link(:rtp) |> via_out(Pad.ref(:output, ssrc)) |> to(:ivf_writter) |> to({:file_sink, ssrc})
        ]
      }

      {{:ok, spec: spec}, state}
    end

    @impl true
    def handle_notification(_notification, _child, _ctx, state) do
      {:ok, state}
    end
  end

  test "depayloading rtp with vp9" do
    test_stream(@rtp_input, @ivf_result_file)
  end

  defp test_stream(input, result_file) do
    {:ok, pipeline} =
      %Testing.Pipeline.Options{
        module: TestPipeline,
        custom_args: %{
          input: input,
          result_file: result_file,
          fmt_mapping: @fmt_mapping
        }
      }
      |> Testing.Pipeline.start_link()

    Testing.Pipeline.play(pipeline)
    assert_pipeline_playback_changed(pipeline, _, :playing)

    %{video: %{ssrc: video_ssrc}} = input

    assert_start_of_stream(pipeline, {:file_sink, ^video_ssrc})

    assert_end_of_stream(pipeline, {:file_sink, ^video_ssrc})
    Testing.Pipeline.stop(pipeline)
    assert_pipeline_playback_changed(pipeline, _, :stopped)
  end
end
