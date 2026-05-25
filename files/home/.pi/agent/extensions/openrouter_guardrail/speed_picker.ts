import { DynamicBorder } from "@earendil-works/pi-coding-agent";
import { Key, matchesKey, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";
import type { PerformanceRow } from "./config";
import { formatRow } from "./format";

const MAX_VISIBLE_ROWS = 12;
type PickerState = {
  query: string;
  selectedIndex: number;
  rows: PerformanceRow[];
  filteredRows: PerformanceRow[];
  done: (row: PerformanceRow | null) => void;
  theme: any;
};
export async function selectSpeedRow(ctx: any, rows: PerformanceRow[]) {
  return ctx.ui.custom<PerformanceRow | null>((tui: any, theme: any, _kb: any, done: any) => {
    const state: PickerState = { query: "", selectedIndex: 0, rows, filteredRows: rows, done, theme };
    const border = new DynamicBorder((text: string) => theme.fg("accent", text));

    return {
      render(width: number) {
        return renderPicker(width, state, border);
      },
      invalidate() {
        border.invalidate();
      },
      handleInput(data: string) {
        handlePickerInput(data, state);
        tui.requestRender();
      },
    };
  });
}
function handlePickerInput(data: string, state: PickerState) {
  if (matchesKey(data, Key.escape)) return state.done(null);
  if (matchesKey(data, Key.enter)) return state.done(state.filteredRows[state.selectedIndex] ?? null);
  if (matchesKey(data, Key.up)) return moveSelection(state, -1);
  if (matchesKey(data, Key.down)) return moveSelection(state, 1);
  if (matchesKey(data, Key.backspace)) return updateQuery(state, state.query.slice(0, -1));
  if (isPrintable(data)) return updateQuery(state, state.query + data);
}
function moveSelection(state: PickerState, delta: number) {
  const count = state.filteredRows.length;
  if (count === 0) return;
  state.selectedIndex = (state.selectedIndex + delta + count) % count;
}
function updateQuery(state: PickerState, query: string) {
  state.query = query;
  const normalized = query.trim().toLowerCase();
  state.filteredRows = normalized
    ? state.rows.filter((row) => row.model.toLowerCase().includes(normalized))
    : state.rows;
  state.selectedIndex = Math.min(state.selectedIndex, Math.max(0, state.filteredRows.length - 1));
}
function renderPicker(width: number, state: PickerState, border: DynamicBorder) {
  const theme = state.theme;
  const query = state.query || theme.fg("dim", "type to filter by model name");
  const lines = [
    ...border.render(width),
    theme.fg("accent", theme.bold("OpenRouter endpoint by throughput")),
    `Filter: ${query}`,
    "",
    ...renderRows(width, state),
    "",
    theme.fg("dim", "type filter • ↑↓ select • enter switch • esc cancel"),
    ...border.render(width),
  ];
  return lines.map((line) => truncateToWidth(line, width));
}
function renderRows(width: number, state: PickerState) {
  if (state.filteredRows.length === 0) return [state.theme.fg("warning", "No matching models")];
  return visibleRows(state).map((row, index) => renderRow(width, row, visibleStart(state) + index, state));
}
function visibleRows(state: PickerState) {
  const start = visibleStart(state);
  return state.filteredRows.slice(start, start + MAX_VISIBLE_ROWS);
}
function visibleStart(state: PickerState) {
  return Math.max(0, Math.min(state.selectedIndex - Math.floor(MAX_VISIBLE_ROWS / 2), state.filteredRows.length - MAX_VISIBLE_ROWS));
}
function renderRow(width: number, row: PerformanceRow, index: number, state: PickerState) {
  const selected = index === state.selectedIndex;
  const prefix = selected ? state.theme.fg("accent", "→ ") : "  ";
  const text = `${index + 1}. ${formatRow(row)}`;
  const available = Math.max(0, width - visibleWidth(prefix));
  return prefix + truncateToWidth(selected ? state.theme.fg("accent", text) : text, available);
}
function isPrintable(data: string) {
  return data.length === 1 && data >= " " && data !== "\x7f";
}
