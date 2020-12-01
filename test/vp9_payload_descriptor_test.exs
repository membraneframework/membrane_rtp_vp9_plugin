defmodule Membrane.RTP.VP9.PayloadDescriptorTest do
  use ExUnit.Case
  alias Membrane.RTP.VP9.PayloadDescriptor

  describe "VP9 Payload Descriptor parser" do
    @doc """
         I P L F B E V Z
        +-+-+-+-+-+-+-+-+
        |1|0|1|1|1|0|0|0| (FIRST OCTET)
        +-+-+-+-+-+-+-+-+
    I:  |0|1 0 1 1 0 1 1| (PICTURE ID)
        +-+-+-+-+-+-+-+-+
    L:  |0 0 1|1|0 1 0|0| (TID | U | SID | D)
        +-+-+-+-+-+-+-+-+
    """

    test "descriptor with picture id and layer indices" do
      payload = <<184, 91, 52, 233, 29, 109, 237>>

      expected_descriptor = %PayloadDescriptor{
        first_octet: 184,
        picture_id: 91,
        tid: 1,
        u: 1,
        d: 0,
        sid: 2
      }

      assert {^expected_descriptor, _} =
               PayloadDescriptor.parse_payload_descriptor(payload)
    end

    @doc """
         I P L F B E V Z
        +-+-+-+-+-+-+-+-+
        |1|0|1|0|1|0|0|0| (FIRST OCTET)
        +-+-+-+-+-+-+-+-+
    I:  |1|1 0 1 1 0 1 1| (EXTENDED PICTURE ID)
        |1 1 1 1 1 1 1 1|
        +-+-+-+-+-+-+-+-+
    L:  |0 0 1|1|0 1 0|0| (TID | U | SID | D)
        +-+-+-+-+-+-+-+-+
        |0 1 0 1 0 1 0 1| TL0PICIDX
        +-+-+-+-+-+-+-+-+
    """

    test "descriptor with extended picture id, layer indices and tl0picidx" do
      payload = <<168, 219, 255, 52, 85, 233, 29, 109, 237>>

      expected_descriptor = %PayloadDescriptor{
        first_octet: 168,
        picture_id: 56319,
        tid: 1,
        u: 1,
        d: 0,
        sid: 2,
        tl0picidx: 85
      }

      assert {^expected_descriptor, <<233, 29, 109, 237>>} =
               PayloadDescriptor.parse_payload_descriptor(payload)
    end

    @doc """
         I P L F B E V Z
        +-+-+-+-+-+-+-+-+
        |1|1|0|1|1|0|0|0| (FIRST OCTET)
        +-+-+-+-+-+-+-+-+
        |0|1 0 1 0 1 0 1| (PICTURE ID)
        +-+-+-+-+-+-+-+-+
        |0 1 0 1 0 1 0 1| (P_DIFF 1)
        +-+-+-+-+-+-+-+-+
        |1 0 1 0 1 0 1 0| (P_DIFF 2)
        +-+-+-+-+-+-+-+-+
    """

    test "descriptor with picture id and two p_diffs" do
      payload = <<216, 85, 85, 170, 233, 29, 109, 237>>

      expected_descriptor = %PayloadDescriptor{
        first_octet: 216,
        picture_id: 85,
        tid: nil,
        u: nil,
        d: nil,
        sid: nil,
        p_diffs: [85, 170],
        tl0picidx: nil,
        ss: nil
      }

      assert {^expected_descriptor, <<233, 29, 109, 237>>} =
               PayloadDescriptor.parse_payload_descriptor(payload)
    end
  end
end
