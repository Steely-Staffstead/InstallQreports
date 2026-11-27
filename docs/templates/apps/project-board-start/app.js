// Start guide for the Project board template, built as a Qanvas app.
// It uses qanvas.setup (granted under App tile > Setup access) to edit the Gantt, delete the example tasks and remove
// its own page, and qanvas.setup.state to remember which steps are done.

const steps = [
  { id: "owners", title: "Add your employees" },
  { id: "groups", title: "Add your projects" },
  { id: "examples", title: "Remove the example tasks" },
  { id: "statuses", title: "Check statuses and Kanban columns" },
  { id: "finish", title: "Finish and remove this start page" }
];

let gantt = null;
let state = { done: {}, open: "" };

const list = document.getElementById("steps");
const errorBox = document.getElementById("error");

function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/g, character => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[character]);
}

function showError(error) {
  errorBox.hidden = !error;
  errorBox.textContent = error ? (error.message || String(error)) : "";
}

function isDone(step) {
  if (step.id === "examples" && gantt && gantt.tasks === 0) return true;
  return state.done[step.id] === true;
}

function applyTheme(theme) {
  const root = document.documentElement.style;
  for (const name of ["surface", "text", "accent", "grid", "positive", "negative"]) {
    if (theme && theme[name]) root.setProperty(`--${name}`, theme[name]);
  }
  if (theme && theme.onAccent) root.setProperty("--on-accent", theme.onAccent);
}

function chips(values, kind) {
  if (!values.length) return '<ul class="chips"><li class="empty">None yet</li></ul>';
  return '<ul class="chips">' + values.map(value =>
    `<li><span>${escapeHtml(value)}</span><button type="button" data-remove="${kind}" data-value="${escapeHtml(value)}" aria-label="Remove ${escapeHtml(value)}">×</button></li>`
  ).join("") + "</ul>";
}

function adder(kind, placeholder) {
  return `<div class="add"><input type="text" data-input="${kind}" placeholder="${placeholder}" aria-label="${placeholder}"><button type="button" class="button" data-add="${kind}">Add</button></div>`;
}

function stepBody(step) {
  if (!gantt) return "<p>Loading the plan…</p>";
  const done = `<button type="button" class="button primary" data-done="${step.id}">Done</button>`;
  if (step.id === "owners") return `<p>Owners are the people tasks are assigned to.</p>${chips(gantt.owners, "owner")}${adder("owner", "Name of employee")}<div class="actions">${done}</div>`;
  if (step.id === "groups") return `<p>Projects group the tasks and form the rows on the Kanban board.</p>${chips(gantt.groups, "group")}${adder("group", "Name of project")}<div class="actions">${done}</div>`;
  if (step.id === "examples") {
    if (!gantt.tasks) return "<p>The plan has no tasks. Add tasks in the Gantt or with ＋ on a Kanban column.</p>";
    return `<p>The plan has ${gantt.tasks} example tasks. Qanvas asks before deleting them, and you can undo with Ctrl+Z.</p><div class="actions"><button type="button" class="button danger" data-clear>Delete ${gantt.tasks} example tasks</button><button type="button" class="button" data-done="examples">Keep them</button></div>`;
  }
  if (step.id === "statuses") return `<p>The Kanban columns follow these statuses: <b>${escapeHtml(gantt.statuses.join(", "))}</b>. Change them in the Gantt settings.</p><div class="actions"><button type="button" class="button" data-open="gantt">Open the Gantt</button>${done}</div>`;
  if (step.id === "finish") return '<p>Remove this start page when you are done. The plan, board and report stay.</p><div class="actions"><button type="button" class="button primary" data-remove-page>Remove the start page</button></div>';
  return "";
}

function render() {
  const doneCount = steps.filter(isDone).length;
  const firstOpen = steps.find(step => !isDone(step));
  const open = state.open || (firstOpen ? firstOpen.id : "");
  document.getElementById("progress-text").textContent = `${doneCount} of ${steps.length} done`;
  document.getElementById("progress-bar").style.width = `${Math.round(doneCount / steps.length * 100)}%`;
  list.innerHTML = steps.map((step, index) => {
    const done = isDone(step);
    const expanded = step.id === open;
    return `<li class="step${done ? " done" : ""}${expanded ? " open" : ""}"><button type="button" class="step-head" data-toggle="${step.id}" aria-expanded="${expanded}"><span class="check" aria-hidden="true">${done ? "✓" : index + 1}</span><b>${step.title}</b></button>${expanded ? `<div class="step-body">${stepBody(step)}</div>` : ""}</li>`;
  }).join("");
}

async function refresh() {
  gantt = await qanvas.setup.gantt();
  render();
}

async function saveState() {
  await qanvas.setup.state.set(state);
}

async function run(task) {
  showError(null);
  try {
    await task();
  } catch (error) {
    showError(error);
  }
}

async function addValue(kind) {
  const input = list.querySelector(`[data-input="${kind}"]`);
  const value = input ? input.value.trim() : "";
  if (!value) return;
  const result = await qanvas.setup.addOption(kind, value);
  if (!result.added) showError(new Error(result.reason || "The name was not added."));
  await refresh();
  const next = list.querySelector(`[data-input="${kind}"]`);
  if (next) next.focus();
}

list.addEventListener("click", event => {
  const target = event.target.closest("button");
  if (!target) return;
  if (target.dataset.toggle) {
    state.open = state.open === target.dataset.toggle ? "-" : target.dataset.toggle;
    render();
    return;
  }
  if (target.dataset.add) run(() => addValue(target.dataset.add));
  if (target.dataset.remove) run(async () => { await qanvas.setup.removeOption(target.dataset.remove, target.dataset.value); await refresh(); });
  if (target.dataset.done) run(async () => { state.done[target.dataset.done] = true; state.open = ""; await saveState(); render(); });
  if (target.hasAttribute("data-clear")) run(async () => { const result = await qanvas.setup.clearTasks(); if (!result.cancelled) { state.open = ""; await refresh(); } });
  if (target.dataset.open) run(() => qanvas.setup.openSettings(target.dataset.open));
  if (target.hasAttribute("data-remove-page")) run(() => qanvas.setup.removeOwnPage());
});

list.addEventListener("keydown", event => {
  const input = event.target.closest("[data-input]");
  if (input && event.key === "Enter") {
    event.preventDefault();
    run(() => addValue(input.dataset.input));
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
