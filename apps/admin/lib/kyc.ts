/** Documents a partner must upload before review, by partner type (from the designs:
 * "5 of 5 documents" for breeders and vets, "4 of 4" for shelters). */
export type DocKind =
  "owner_id" | "cac" | "licence" | "facility_photo" | "vet_reference" | "payout_account";

export const REQUIRED_DOCS: Record<string, DocKind[]> = {
  vet: ["owner_id", "licence", "facility_photo", "vet_reference", "payout_account"],
  breeder: ["owner_id", "cac", "facility_photo", "vet_reference", "payout_account"],
  shelter: ["owner_id", "cac", "facility_photo", "payout_account"],
  service: ["owner_id", "cac", "facility_photo", "payout_account"],
};

export const DOC_LABELS: Record<DocKind, { group: string; label: string }> = {
  owner_id: { group: "ID document", label: "Owner ID" },
  cac: { group: "Certificate", label: "CAC registration" },
  licence: { group: "Certificate", label: "Veterinary licence" },
  facility_photo: { group: "Photos", label: "Facility photos" },
  vet_reference: { group: "Letter", label: "Vet reference" },
  payout_account: { group: "Payouts", label: "Payout account" },
};

export function documentProgress(
  type: string,
  uploaded: string[],
): { have: number; need: number; missing: DocKind[] } {
  const required = REQUIRED_DOCS[type] ?? REQUIRED_DOCS.service!;
  const set = new Set(uploaded);
  const missing = required.filter((k) => !set.has(k));
  return { have: required.length - missing.length, need: required.length, missing };
}

export const KYC_CHECKS = [
  { key: "name_matches", label: "Name on ID matches the registered owner or director" },
  { key: "address_in_area", label: "Address is in the Lagos service area" },
  { key: "no_duplicates", label: "No duplicate accounts or past bans" },
  { key: "reference_confirmed", label: "Reference confirmed by phone" },
] as const;

export const PARTNER_TYPE_LABELS: Record<string, string> = {
  vet: "Vet",
  service: "Services",
  breeder: "Breeder",
  shelter: "Shelter",
};
