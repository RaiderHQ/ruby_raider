// Actionability checks for Raider::Actionability. Runs as an execute_script body:
// arguments[0] is the element, arguments[1] the Array of check names to run.
// Returns null when every check passes, else { check, covering? } for the first failure.
// Read-only apart from scrolling: it never sets styles, focuses, or dispatches events.
const el = arguments[0];
const names = arguments[1];
const isOption = el.tagName === 'OPTION';

const describe = (node) => {
  let text = node.tagName.toLowerCase();
  if (node.id) text += '#' + node.id;
  const classes = Array.from(node.classList || []).slice(0, 2);
  classes.forEach((name) => { text += '.' + name; });
  return text;
};

// Not display: none on the node or any ancestor (a file input may have an empty rect).
const displayed = (node) => {
  if (node.checkVisibility) return node.checkVisibility();
  for (let current = node; current; current = current.parentElement) {
    if (window.getComputedStyle(current).display === 'none') return false;
  }
  return true;
};

const visible = () => {
  const target = isOption ? (el.closest('select') || el) : el;
  const style = window.getComputedStyle(target);
  if (target.tagName === 'INPUT' && target.type === 'file') return displayed(target);
  if (target.checkVisibility) return target.checkVisibility({ visibilityProperty: true });
  const rect = target.getBoundingClientRect();
  return rect.width > 0 && rect.height > 0 && style.visibility !== 'hidden';
};

const enabled = () => {
  if (el.disabled) return false;
  const fieldset = el.closest('fieldset[disabled]');
  if (!fieldset) return true;
  const legend = fieldset.querySelector(':scope > legend');
  return !!legend && legend.contains(el);
};

const editable = () => {
  if (el.isContentEditable) return true;
  const tag = el.tagName;
  if (tag === 'SELECT') return true;
  return (tag === 'INPUT' || tag === 'TEXTAREA') && !el.readOnly;
};

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
  if (el.closest('[inert]')) return false;
  const dialog = modalDialog();
  return !dialog || dialog.contains(el);
};

const stable = () => {
  if (isOption) return true;
  window.__raiderRects = window.__raiderRects || new WeakMap();
  const box = el.getBoundingClientRect();
  const now = [box.x + window.scrollX, box.y + window.scrollY, box.width, box.height].map(Math.round).join(',');
  const before = window.__raiderRects.get(el);
  window.__raiderRects.set(el, now);
  return before === now;
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

const inViewport = () => {
  const box = el.getBoundingClientRect();
  return box.top >= 0 && box.left >= 0 && box.bottom <= window.innerHeight && box.right <= window.innerWidth;
};

if (!isOption && !inViewport()) el.scrollIntoView({ block: 'center', inline: 'center' });

const simple = { visible: visible, enabled: enabled, editable: editable, inert: notInert, stable: stable };

for (const name of names) {
  if (name === 'events') {
    const failure = events();
    if (failure) return failure;
  } else if (!simple[name]()) {
    return { check: name };
  }
}
return null;
