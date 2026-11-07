// Actionability checks for Raider::Actionability. Runs as an execute_script body:
// arguments[0] is the element, arguments[1] the Array of check names to run.
// Returns null when every check passes, else { check, covering? } for the first failure.
// Read-only apart from scrolling: it never sets styles, focuses, or dispatches events.
const el = arguments[0];
const names = arguments[1];
const isOption = el.tagName === 'OPTION';
const typing = names.includes('editable');

const describe = (node) => {
  let text = node.tagName.toLowerCase();
  if (node.id) text += '#' + node.id;
  const classes = Array.from(node.classList || []).slice(0, 2);
  classes.forEach((name) => { text += '.' + name; });
  return text;
};

// One step up the composed tree: the parent, or the host when leaving a shadow root.
const up = (node) => node.parentNode || node.host || null;

// First element on the composed path from node to the root (node included) that passes test.
const composedClosest = (node, test) => {
  for (let current = node; current; current = up(current)) {
    if (current.nodeType === 1 && test(current)) return current;
  }
  return null;
};

const composedContains = (ancestor, node) => composedClosest(node, (current) => current === ancestor) !== null;

// Not display: none on the node or any ancestor (a file input may have an empty rect).
const displayed = (node) => {
  if (node.checkVisibility) return node.checkVisibility();
  return !composedClosest(node, (current) => window.getComputedStyle(current).display === 'none');
};

const visible = () => {
  const target = isOption ? (el.closest('select') || el) : el;
  const style = window.getComputedStyle(target);
  if (target.tagName === 'INPUT' && target.type === 'file') {
    // File inputs are routinely hidden behind a styled label, so typing a path skips visible.
    return typing || displayed(target);
  }
  const rect = target.getBoundingClientRect();
  if (!(rect.width > 0 && rect.height > 0)) return false;
  if (target.checkVisibility) return target.checkVisibility({ visibilityProperty: true });
  return style.visibility !== 'hidden';
};

const enabled = () => {
  if (el.disabled) return false;
  const fieldset = composedClosest(el, (node) => node.tagName === 'FIELDSET' && node.hasAttribute('disabled'));
  if (!fieldset) return true;
  const legend = fieldset.querySelector(':scope > legend');
  return !!legend && composedContains(legend, el);
};

// Keys can go to any element (body for Escape, a button for Enter); only a readonly field refuses them.
const editable = () => !((el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') && el.readOnly);

const modalDialog = () => {
  try {
    const modal = document.querySelector('dialog:modal');
    if (modal) return modal;
  } catch (error) {
    // :modal is not supported; fall through to the open-dialog scan.
  }
  return Array.from(document.querySelectorAll('dialog[open]')).find((dialog) => {
    try { return dialog.matches(':modal'); } catch (error) { return false; }
  }) || null;
};

const notInert = () => {
  if (composedClosest(el, (node) => node.hasAttribute('inert'))) return false;
  const dialog = modalDialog();
  return !dialog || composedContains(dialog, el);
};

const stable = () => {
  if (isOption) return true;
  window.__raiderRects = window.__raiderRects || new WeakMap();
  const box = el.getBoundingClientRect();
  const now = [box.x + window.scrollX, box.y + window.scrollY, box.width, box.height].map(Math.round).join(',');
  const before = window.__raiderRects.get(el);
  window.__raiderRects.set(el, now);
  return before === undefined ? 'first' : before === now;
};

const clamp = (value, max) => Math.max(0, Math.min(Math.round(value), Math.max(max - 1, 0)));

// Returns null when the centre point reaches the element, else a failure with covering.
const events = () => {
  if (isOption) return null;
  const box = el.getBoundingClientRect();
  const x = clamp(box.x + box.width / 2, window.innerWidth);
  const y = clamp(box.y + box.height / 2, window.innerHeight);
  const root = el.getRootNode();
  const hit = (root.elementFromPoint ? root : document).elementFromPoint(x, y);
  if (hit && el.contains(hit)) return null;
  return hit ? { check: 'events', covering: { element: describe(hit), x: x, y: y } } : { check: 'events' };
};

const within = (box, outer) => (
  box.top >= outer.top && box.left >= outer.left && box.bottom <= outer.bottom && box.right <= outer.right
);

// Inside the viewport (without scrollbars) and inside every clipping ancestor (overflow not visible).
const unclipped = () => {
  const box = el.getBoundingClientRect();
  const root = document.documentElement;
  if (!within(box, { top: 0, left: 0, bottom: root.clientHeight, right: root.clientWidth })) return false;
  return !composedClosest(up(el) || el, (node) => {
    if (node === root || node === document.body) return false;
    const style = window.getComputedStyle(node);
    if (style.overflowX === 'visible' && style.overflowY === 'visible') return false;
    return !within(box, node.getBoundingClientRect());
  });
};

if (!isOption && !unclipped()) el.scrollIntoView({ block: 'center', inline: 'center' });

const simple = { visible: visible, enabled: enabled, editable: editable, inert: notInert, stable: stable };

for (const name of names) {
  if (name === 'events') {
    const failure = events();
    if (failure) return failure;
  } else {
    const result = simple[name]();
    if (result === 'first') return { check: name, first: true };
    if (!result) return { check: name };
  }
}
return null;
