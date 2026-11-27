// Start guide for the Task list template, built as a Qanvas app.
// It uses qanvas.setup (granted under App tile > Setup access) to change the choices of the Status and Priority fields,
// choose the board columns, delete the example rows and remove its own page. Progress is kept with qanvas.setup.state.

const steps = [
  { id: "status", title: "Choose your statuses" },
  { id: "priority", title: "Choose your priorities" },
  { id: "board", title: "Choose the board columns" },
  { id: "examples", title: "Remove the example tasks" },
  { id: "finish", title: "Finish and remove this start page" }
];

let list = null;
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

function field(name) {
  return list ? list.fields.find(item => item.field === name) : null;
}

function isDone(step) {
  if (step.id === "examples" && list && list.rows === 0) return true;
  return state.done[step.id] === true;
}

function applyTheme(theme) {
  const root = document.documentElement.style;
  for (const name of ["surface", "text", "accent", "grid", "positive", "negative"]) {
    if (theme && theme[name]) root.setProperty(`--${name}`, theme[name]);
  }
  if (theme && theme.onAccent) root.setProperty("--on-accent", theme.onAccent);
}

function choiceEditor(name, placeholder) {
  const choices = field(name) ? field(name).choices : [];
  const chips = choices.map(value =>
    `<li><span>${escapeHtml(value)}</span><button type="button" data-remove-choice="${name}" data-value="${escapeHtml(value)}" aria-label="Remove ${escapeHtml(value)}">×</button></li>`
  ).join("");
  return `<ul class="chips">${chips}</ul><div class="add"><input type="text" data-choice-input="${name}" placeholder="${placeholder}" aria-label="${placeholder}"><button type="button" class="button" data-add-choice="${name}">Add</button></div>`;
}

function stepBody(step) {
  if (!list) return "<p>Loading the list…</p>";
  const done = `<button type="button" class="button primary" data-done="${step.id}">Done</button>`;
  if (step.id === "status") return `<p>Statuses are the columns on the board. A task keeps its status until you change it, also if you remove that status here.</p>${choiceEditor("status", "New status")}<div class="actions">${done}</div>`;
  if (step.id === "priority") return `<p>Priorities show on each card.</p>${choiceEditor("priority", "New priority")}<div class="actions">${done}</div>`;
  if (step.id === "board") {
    const options = list.fields.filter(item => item.type === "choice").map(item =>
      `<label class="option"><input type="radio" name="board-column" value="${item.field}" ${list.board.columnField === item.field ? "checked" : ""}> ${escapeHtml(item.label)}</label>`
    ).join("");
    return `<p>Choose which field becomes the columns on the board.</p><div class="options">${options}</div><div class="actions"><button type="button" class="button" data-apply-board>Use this</button>${done}</div>`;
  }
  if (step.id === "examples") {
    if (!list.rows) return "<p>The list is empty. Add tasks with ＋ on a board column.</p>";
    return `<p>The list has ${list.rows} example tasks. Qanvas asks before deleting them, and you can undo with Ctrl+Z.</p><div class="actions"><button type="button" class="button danger" data-clear>Delete ${list.rows} example tasks</button><button type="button" class="button" data-done="examples">Keep them</button></div>`;
  }
  if (step.id === "finish") return '<p>Remove this start page when you are done. The task list stays.</p><div class="actions"><button type="button" class="button primary" data-remove-page>Remove the start page</button></div>';
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
  list = await qanvas.setup.list();
  render();
}

async function run(task) {
  showError(null);
  try {
    await task();
  } catch (error) {
    showError(error);
  }
}

async function setChoices(name, values) {
  await qanvas.setup.setListChoices(name, values);
  await refresh();
}

async function addChoice(name) {
  const input = stepList.querySelector(`[data-choice-input="${name}"]`);
  const value = input ? input.value.trim() : "";
  if (!value) return;
  await setChoices(name, [...field(name).choices, value]);
  const next = stepList.querySelector(`[data-choice-input="${name}"]`);
  if (next) next.focus();
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
  if (target.dataset.addChoice) run(() => addChoice(target.dataset.addChoice));
  if (target.dataset.removeChoice) run(() => setChoices(target.dataset.removeChoice, field(target.dataset.removeChoice).choices.filter(value => value !== target.dataset.value)));
  if (target.hasAttribute("data-apply-board")) run(async () => {
    const chosen = stepList.querySelector('input[name="board-column"]:checked');
    if (chosen) await qanvas.setup.setListBoard({ columnField: chosen.value, viewMode: "board" });
    await refresh();
  });
  if (target.dataset.done) run(() => markDone(target.dataset.done));
  if (target.hasAttribute("data-clear")) run(async () => { const result = await qanvas.setup.clearList(); if (!result.cancelled) { state.open = ""; await refresh(); } });
  if (target.hasAttribute("data-remove-page")) run(() => qanvas.setup.removeOwnPage());
});

stepList.addEventListener("keydown", event => {
  const input = event.target.closest("[data-choice-input]");
  if (input && event.key === "Enter") {
    event.preventDefault();
    run(() => addChoice(input.dataset.choiceInput));
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
