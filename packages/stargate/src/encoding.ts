import { Bech32 } from "@cosmjs/encoding";

export function fromBech32(input: string) {
  return Bech32.decode(input);
}
