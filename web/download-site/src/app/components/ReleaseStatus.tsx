import {
  statusClass,
  statusLabel,
  type ReleaseStatus as ReleaseStatusValue,
} from "@/lib/releases";

export function ReleaseStatus({ status }: { status: ReleaseStatusValue }) {
  return (
    <span className={"release-status " + statusClass(status)}>
      <span className="status-dot" aria-hidden="true" />
      {statusLabel(status)}
    </span>
  );
}
