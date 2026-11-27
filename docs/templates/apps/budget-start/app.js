// Start guide for the Budget template, built as a Qanvas app.
// The budget is a Report Grid: row 1 holds the period names (B1:E1), rows 2-11 the departments (column A) with amounts
// (B:E) and a total per department (F), and row 12 the column totals. The app uses qanvas.setup to read and write cells,
// clear the example amounts (Qanvas asks first) and remove its own page.

const firstRow = 2;
const lastRow = 11;
const maxDepartments = lastRow - firstRow + 1;

const steps = [
  { id: "periods", title: "Name the periods" },
  { id: "departments", title: "Add your departments" },
  { id: "amounts", title: "Clear the example amounts" },
  { id: "finish", title: "Finish and remove this start page" }
];

let periods = [];
let departments = [];
let amounts = 0;
let state = { done: {}, open: "" };

const stepList = document.getElementById("steps");
const errorBox = document.getElementById("error");

function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/g, character => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[character]);
}

function showError(error) {
  errorBox.hidden = !error;
  errorBox.textContent = error ? (error.message || String(error)) : "";
}

function isDone(step) {
  if (step.id === "amounts" && amounts === 0) return true;
  return state.done[step.id] === true;
}

function applyTheme(theme) {
  const root = document.documentElement.style;
  for (const name of ["surface", "text", "accent", "grid", "positive", "negative"]) {
    if (theme && theme[name]) root.setProperty(`--${name}`, theme[name]);
  }
  if (theme && theme.onAccent) root.setProperty("--on-accent", theme.onAccent);
}

function stepBody(step) {
  const done = `<button type="button" class="button primary" data-done="${step.id}">Done</button>`;
  if (step.id === "periods") {
    const inputs = periods.map((value, index) => `<input type="text" data-period="${index}" value="${escapeHtml(value)}" aria-label="Period ${index + 1}">`).join("");
    return `<p>The four amount columns. Use quarters, months or anything that fits your budget.</p><div class="periods">${inputs}</div><div class="actions"><button type="button" class="button" data-save-periods>Save names</button>${done}</div>`;
  }
  if (step.id === "departments") {
    const chips = departments.map(value =>
      `<li><span>${escapeHtml(value)}</span><button type="button" data-remove-department="${escapeHtml(value)}" aria-label="Remove ${escapeHtml(value)}">×</button></li>`
    ).join("") || '<li class="empty">None yet</li>';
    return `<p>One row per department, up to ${maxDepartments}. Totals are calculated for you.</p><ul class="chips">${chips}</ul><div class="add"><input type="text" data-department-input placeholder="Name of department" aria-label="Name of department"><button type="button" class="button" data-add-department>Add</button></div><div class="actions">${done}</div>`;
  }
  if (step.id === "amounts") {
    if (!amounts) return "<p>There are no amounts in the budget. Type them straight into the grid.</p>";
    return `<p>The budget has ${amounts} example amounts. Qanvas asks before clearing them; names and totals stay, and you can undo with Ctrl+Z.</p><div class="actions"><button type="button" class="button danger" data-clear>Clear ${amounts} amounts</button><button type="button" class="button" data-done="amounts">Keep them</button></div>`;
  }
  if (step.id === "finish") return '<p>Remove this start page when you are done. The budget stays.</p><div class="actions"><button type="button" class="button primary" data-remove-page>Remove the start page</button></div>';
  return "";
}

function render() {
  const doneCount = steps.filter(isDone).length;
  const firstOpen = steps.find(step => !isDone(step));
  const open = state.open || (firstOpen ? firstOpen.id : "");
  document.getElementById("progress-text").textContent = `${doneCount} of ${steps.length} done`;
  document.getElementById("progress-bar").style.width = `${Math.round(doneCount / steps.length * 100)}%`;
  stepList.innerHTML = steps.map((step, index) => {
    const done = isDone(step);
    const expanded = step.id === open;
    return `<li class="step${done ? " done" : ""}${expanded ? " open" : ""}"><button type="button" class="step-head" data-toggle="${step.id}" aria-expanded="${expanded}"><span class="check" aria-hidden="true">${done ? "✓" : index + 1}</span><b>${step.title}</b></button>${expanded ? `<div class="step-body">${stepBody(step)}</div>` : ""}</li>`;
  }).join("");
}

async function refresh() {
  const header = await qanvas.setup.readGrid("B1:E1");
  periods = header.values[0];
  const names = await qanvas.setup.readGrid(`A${firstRow}:A${lastRow}`);
  departments = names.values.map(row => row[0]).filter(value => value.trim());
  const values = await qanvas.setup.readGrid(`B${firstRow}:E${lastRow}`);
  amounts = values.values.flat().filter(value => String(value).trim() && !String(value).startsWith("=")).length;
  render();
}

// Departments fill rows 2-11 from the top; each named row gets its total formula.
async function writeDepartments(names) {
  if (names.length > maxDepartments) throw new Error(`The budget has room for ${maxDepartments} departments.`);
  const rows = [];
  for (let index = 0; index < maxDepartments; index++) rows.push([names[index] || ""]);
  await qanvas.setup.writeGrid(`A${firstRow}`, rows);
  const totals = [];
  for (let index = 0; index < maxDepartments; index++) {
    const row = firstRow + index;
    totals.push([names[index] ? `=SUM(B${row}:E${row})` : ""]);
  }
  await qanvas.setup.writeGrid(`F${firstRow}`, totals);
  await refresh();
}

async function addDepartment() {
  const input = stepList.querySelector("[data-department-input]");
  const value = input ? input.value.trim() : "";
  if (!value) return;
  if (departments.some(name => name.toLowerCase() === value.toLowerCase())) throw new Error(`${value} is already in the budget.`);
  await writeDepartments([...departments, value]);
  const next = stepList.querySelector("[data-department-input]");
  if (next) next.focus();
}

async function run(task) {
  showError(null);
  try {
    await task();
  } catch (error) {
    showError(error);
  }
}

async function markDone(id) {
  state.done[id] = true;
  state.open = "";
  await qanvas.setup.state.set(state);
  render();
}

stepList.addEventListener("click", event => {
  const target = event.target.closest("button");
  if (!target) return;
  if (target.dataset.toggle) {
    state.open = state.open === target.dataset.toggle ? "-" : target.dataset.toggle;
    render();
    return;
  }
  if (target.hasAttribute("data-save-periods")) run(async () => {
    const names = [...stepList.querySelectorAll("[data-period]")].map(input => input.value.trim());
    await qanvas.setup.writeGrid("B1", [names]);
    await refresh();
  });
  if (target.hasAttribute("data-add-department")) run(addDepartment);
  if (target.dataset.removeDepartment) run(() => writeDepartments(departments.filter(name => name !== target.dataset.removeDepartment)));
  if (target.dataset.done) run(() => markDone(target.dataset.done));
  if (target.hasAttribute("data-clear")) run(async () => { const result = await qanvas.setup.clearGrid(`B${firstRow}:E${lastRow}`); if (!result.cancelled) { state.open = ""; await refresh(); } });
  if (target.hasAttribute("data-remove-page")) run(() => qanvas.setup.removeOwnPage());
});

stepList.addEventListener("keydown", event => {
  if (event.target.closest("[data-department-input]") && event.key === "Enter") {
    event.preventDefault();
    run(addDepartment);
  }
});

window.addEventListener("message", event => {
  if (event.data?.type !== "qanvas.init") return;
  applyTheme(event.data.payload?.theme);
  run(async () => {
    state = { done: {}, open: "", ...((await qanvas.setup.state.get()) || {}) };
    await refresh();
  });
});

parent.postMessage({ type: "qanvas.ready" }, "*");
