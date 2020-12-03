defmodule Membrane.RTP.VP9.PayloadDescriptor do
  @moduledoc """
  Defines a structure representing VP9 payload descriptor
  Described here: https://tools.ietf.org/html/draft-ietf-payload-vp9-10#section-4.2

  Flexible mode:
  ```
         0 1 2 3 4 5 6 7
        +-+-+-+-+-+-+-+-+
        |I|P|L|F|B|E|V|Z| (REQUIRED)
        +-+-+-+-+-+-+-+-+
   I:   |M| PICTURE ID  | (REQUIRED)
        +-+-+-+-+-+-+-+-+
   M:   | EXTENDED PID  | (RECOMMENDED)
        +-+-+-+-+-+-+-+-+
   L:   | TID |U| SID |D| (CONDITIONALLY RECOMMENDED)
        +-+-+-+-+-+-+-+-+                             -\
   P,F: | P_DIFF      |N| (CONDITIONALLY REQUIRED)    - up to 3 times
        +-+-+-+-+-+-+-+-+                             -/
   V:   | SS            |
        | ..            |
        +-+-+-+-+-+-+-+-+
  ```
  Non-flexible mode:
  ```
         0 1 2 3 4 5 6 7
        +-+-+-+-+-+-+-+-+
        |I|P|L|F|B|E|V|Z| (REQUIRED)
        +-+-+-+-+-+-+-+-+
   I:   |M| PICTURE ID  | (RECOMMENDED)
        +-+-+-+-+-+-+-+-+
   M:   | EXTENDED PID  | (RECOMMENDED)
        +-+-+-+-+-+-+-+-+
   L:   | TID |U| SID |D| (CONDITIONALLY RECOMMENDED)
        +-+-+-+-+-+-+-+-+
        |   TL0PICIDX   | (CONDITIONALLY REQUIRED)
        +-+-+-+-+-+-+-+-+
   V:   | SS            |
        | ..            |
        +-+-+-+-+-+-+-+-+
  ```
  """

  @type first_octet :: 0..255

  @type picture_id :: 0..32767

  @type tid :: 0..7

  @type u :: 0..1

  @type d :: 0..1

  @type sid :: 0..7

  @type p_diff :: 0..255

  @type tl0picidx :: 0..255

  defmodule PGDescription do
    alias Membrane.RTP.VP9.PayloadDescriptor

    @type t :: %__MODULE__{
            tid: PayloadDescriptor.tid(),
            u: PayloadDescriptor.u(),
            p_diffs: list(PayloadDescriptor.p_diff())
          }

    defstruct [:tid, :u, p_diffs: []]
  end

  defmodule SSDimension do
    @type t :: %__MODULE__{
            width: 0..65535,
            height: 0..65535
          }

    @enforce_keys [:width, :height]
    defstruct @enforce_keys
  end

  defmodule ScalabilityStructure do
    alias Membrane.RTP.VP9.PayloadDescriptor
    alias Membrane.RTP.VP9.PayloadDescriptor.{SSDimension, PGDescription}

    @type t :: %__MODULE__{
            first_octet: PayloadDescriptor.first_octet(),
            dimensions: list(SSDimension.t()),
            pg_descriptions: list(PGDescription.t())
          }

    @enforce_keys [:first_octet]
    defstruct [:first_octet, dimensions: [], pg_descriptions: []]
  end

  @type t :: %__MODULE__{
          first_octet: first_octet(),
          picture_id: picture_id(),
          tid: tid(),
          u: u(),
          sid: sid(),
          d: d(),
          p_diffs: list(p_diff()),
          tl0picidx: tl0picidx(),
          scalability_structure: ScalabilityStructure.t()
        }

  defstruct [
    :first_octet,
    :picture_id,
    :tid,
    :u,
    :sid,
    :d,
    :tl0picidx,
    :scalability_structure,
    p_diffs: []
  ]

  @spec parse_payload_descriptor(binary()) :: {:error, :malformed_data} | {:ok, {t(), binary()}}
  def parse_payload_descriptor(raw_payload)

  def parse_payload_descriptor(<<header::binary-size(1), rest::binary()>>)
      when byte_size(rest) > 0 do
    <<i::1, _p::1, _l::1, f::1, _bevz::4>> = header

    if i != f do
      {:error, :malformed_data}
    else
      case get_pid(header, rest, %__MODULE__{first_octet: :binary.decode_unsigned(header)}) do
        {:ok, {descriptor_acc, rest}} ->
          case get_layer_indices(header, rest, descriptor_acc) do
            {:ok, {descriptor_acc, rest}} ->
              case get_pdiffs(header, rest, 0, descriptor_acc) do
                {:ok, {descriptor_acc, rest}} ->
                  case get_scalability_structure(header, rest) do
                    {:ok, {ss, rest}} ->
                      {:ok, {%{descriptor_acc | scalability_structure: ss}, rest}}

                    _ ->
                      {:error, :malformed_data}
                  end

                _ ->
                  {:error, :malformed_data}
              end

            _ ->
              {:error, :malformed_data}
          end

        _ ->
          {:error, :malformed_data}
      end
    end
  end

  def parse_payload_descriptor(_), do: {:error, :malformed_data}

  # no picture id (PID)
  defp get_pid(<<0::1, _::7>>, rest, descriptor_acc) when byte_size(rest) > 0,
    do: {:ok, {descriptor_acc, rest}}

  # picture id (PID) present
  defp get_pid(<<1::1, _::7>>, <<pid::binary-size(1), rest::binary()>>, descriptor_acc)
       when byte_size(rest) > 0 do
    case pid do
      <<0::1, _rest_of_pid::7>> ->
        {:ok, {%{descriptor_acc | picture_id: :binary.decode_unsigned(pid)}, rest}}

      <<1::1, _rest_of_pid::7>> ->
        <<second_byte::binary-size(1), rest::binary()>> = rest
        {:ok, {%{descriptor_acc | picture_id: :binary.decode_unsigned(pid <> second_byte)}, rest}}

      _ ->
        {:error, :malformed_data}
    end
  end

  defp get_pid(_, _, _), do: {:error, :malformed_data}

  # no layer indices
  defp get_layer_indices(<<_i::1, _p::1, 0::1, _::5>>, rest, descriptor_acc)
       when byte_size(rest) > 0,
       do: {:ok, {descriptor_acc, rest}}

  # layer indices present
  defp get_layer_indices(<<_i::1, _p::1, 1::1, f::1, _::4>>, rest, descriptor_acc)
       when byte_size(rest) > 0 do
    case f do
      # TL0PICIDX present
      0 ->
        if byte_size(rest) > 2 do
          <<tid::3, u::1, sid::3, d::1, tl0picidx, rest::binary()>> = rest
          {:ok, {%{descriptor_acc | tid: tid, u: u, sid: sid, d: d, tl0picidx: tl0picidx}, rest}}
        else
          {:error, :malformed_data}
        end

      # no TL0PICIDX
      _ ->
        if byte_size(rest) > 1 do
          <<tid::3, u::1, sid::3, d::1, rest::binary()>> = rest
          {:ok, {%{descriptor_acc | tid: tid, u: u, sid: sid, d: d}, rest}}
        else
          {:error, :malformed_data}
        end
    end
  end

  defp get_layer_indices(_, _, _), do: {:error, :malformed_data}

  defp get_pdiffs(
         <<_i::1, 1::1, _l::1, 1::1, _::4>> = header,
         <<p_diff::binary-size(1), rest::binary>>,
         diff_count,
         descriptor_acc
       )
       when diff_count < 3 do
    <<_::7, n::1>> = p_diff

    if n == 1 do
      case get_pdiffs(header, rest, diff_count + 1, descriptor_acc) do
        {:ok, {descriptor_acc, rest}} ->
          {:ok,
           {%{
              descriptor_acc
              | p_diffs: [:binary.decode_unsigned(p_diff) | descriptor_acc.p_diffs]
            }, rest}}

        _ ->
          {:error, :malformed_data}
      end
    else
      {:ok,
       {%{descriptor_acc | p_diffs: [:binary.decode_unsigned(p_diff) | descriptor_acc.p_diffs]},
        rest}}
    end
  end

  defp get_pdiffs(_, rest, _, descriptor_acc) when byte_size(rest) > 0,
    do: {:ok, {descriptor_acc, rest}}

  defp get_pdiffs(_, _, _, _), do: {:error, :malformed_data}

  # no scalability structure
  defp get_scalability_structure(<<_iplfbe::6, 0::1, _z::1>>, rest), do: {:ok, {nil, rest}}

  defp get_scalability_structure(<<_iplfbe::6, 1::1, _z::1>>, rest) do
    <<ss_header::binary-size(1), rest::binary()>> = rest

    case ss_get_widths_heights(ss_header, rest, 0, []) do
      {:ok, {widths_and_heights, rest}} ->
        case ss_get_pg_descriptions(ss_header, rest) do
          {:ok, {pg_descriptions, rest}} ->
            {:ok,
             {%ScalabilityStructure{
                first_octet: :binary.decode_unsigned(ss_header),
                dimensions: widths_and_heights,
                pg_descriptions: pg_descriptions
              }, rest}}

          _ ->
            {:error, :malformed_data}
        end

      _ ->
        {:error, :malformed_data}
    end
  end

  defp ss_get_widths_heights(<<_n_s::3, 0::1, _g::1, _::3>>, rest, _count, dimensions),
    do: {:ok, {dimensions, rest}}

  defp ss_get_widths_heights(<<n_s::3, 1::1, _g::1, _::3>> = ss_header, rest, count, dimensions)
       when count <= n_s and byte_size(rest) > 4 do
    <<width::binary-size(2), height::binary-size(2), rest::binary()>> = rest

    case ss_get_widths_heights(ss_header, rest, count + 1, dimensions) do
      {:ok, {next_dims, rest}} ->
        {:ok,
         {[
            %SSDimension{
              width: :binary.decode_unsigned(width),
              height: :binary.decode_unsigned(height)
            }
            | next_dims
          ], rest}}

      _ ->
        {:error, :malformed_data}
    end
  end

  defp ss_get_widths_heights(<<n_s::3, 1::1, _g::1, _::3>>, rest, count, dimensions)
       when count == n_s + 1,
       do: {:ok, {dimensions, rest}}

  defp ss_get_widths_heights(_, _, _, _), do: {:error, :malformed_data}

  defp ss_get_pg_descriptions(<<_n_s::3, _y::1, 1::1, _::3>>, rest) do
    <<n_g, rest::binary()>> = rest

    1..n_g
    |> Enum.reduce({:ok, {[], rest}}, fn _i, acc ->
      case acc do
        {:ok, {accumulated, rest}} ->
          case ss_get_pg_description(rest) do
            {:ok, {pg_description, rest}} ->
              {:ok, {accumulated ++ [pg_description], rest}}

            _ ->
              {:error, :malformed_data}
          end

        _ ->
          {:error, :malformed_data}
      end
    end)
  end

  defp ss_get_pg_descriptions(_, rest), do: {:ok, {[], rest}}

  defp ss_get_pg_description(<<_tid::3, _u::1, r::2, _::2, rest::binary()>>)
       when byte_size(rest) < r,
       do: {:error, :malformed_data}

  defp ss_get_pg_description(<<tid::3, u::1, r::2, _::2, rest::binary()>>) do
    pg_description = %PGDescription{tid: tid, u: u}

    case r do
      0 ->
        {pg_description, rest}

      _ ->
        <<p_diffs::binary-size(r), rest::binary()>> = rest

        {:ok,
         {:binary.bin_to_list(p_diffs)
          |> Enum.reduce(pg_description, fn p_diff, acc ->
            %{acc | p_diffs: acc.p_diffs ++ [p_diff]}
          end), rest}}
    end
  end

  defp ss_get_pg_description(_), do: {:error, :malformed_data}
end
