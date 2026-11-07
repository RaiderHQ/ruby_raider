(function () {
  'use strict';
  if (window.__raider && window.__raider.role) { return; }

  // Keep in step with Raider::ROLES in lib/ruby_raider/runtime/by_role.rb.
  var ROLES = ('alert alertdialog application article banner blockquote button caption cell checkbox code ' +
    'columnheader combobox complementary contentinfo definition deletion dialog directory document emphasis feed ' +
    'figure form generic grid gridcell group heading img insertion link list listbox listitem log main marquee math ' +
    'menu menubar menuitem menuitemcheckbox menuitemradio meter navigation none note option paragraph presentation ' +
    'progressbar radio radiogroup region row rowgroup rowheader scrollbar search searchbox separator slider ' +
    'spinbutton status strong subscript superscript switch tab table tablist tabpanel term textbox time timer ' +
    'toolbar tooltip tree treegrid treeitem').split(' ');

  var NAME_FROM_CONTENT = ('button link heading cell option tab menuitem treeitem row gridcell columnheader ' +
    'rowheader switch checkbox radio tooltip menuitemcheckbox menuitemradio').split(' ');

  // Implicit roles by tag; tags that need a decision are handled in implicitRole.
  var TAG_ROLES = {
    article: 'article', aside: 'complementary', button: 'button', datalist: 'listbox', details: 'group',
    dialog: 'dialog', fieldset: 'group', figure: 'figure', form: 'form', h1: 'heading', h2: 'heading',
    h3: 'heading', h4: 'heading', h5: 'heading', h6: 'heading', hr: 'separator', main: 'main', math: 'math',
    menu: 'list', ol: 'list', ul: 'list', meter: 'meter', nav: 'navigation', option: 'option', output: 'status',
    progress: 'progressbar', table: 'table', tbody: 'rowgroup', thead: 'rowgroup', tfoot: 'rowgroup',
    td: 'cell', textarea: 'textbox', tr: 'row', div: 'generic', span: 'generic'
  };

  var INPUT_ROLES = {
    button: 'button', image: 'button', reset: 'button', submit: 'button', checkbox: 'checkbox', radio: 'radio',
    range: 'slider', number: 'spinbutton', search: 'searchbox', email: 'textbox', tel: 'textbox',
    text: 'textbox', url: 'textbox', password: 'textbox'
  };

  var LIST_INPUTS = ['search', 'email', 'tel', 'text', 'url'];

  function has(object, key) { return Object.prototype.hasOwnProperty.call(object, key); }

  function normalize(text) { return String(text).replace(/\s+/g, ' ').trim(); }

  function explicitRole(el) {
    var tokens = (el.getAttribute('role') || '').toLowerCase().split(/\s+/);
    for (var i = 0; i < tokens.length; i++) {
      if (ROLES.indexOf(tokens[i]) >= 0) { return tokens[i]; }
    }
    return null;
  }

  function insideGrid(el) {
    for (var n = el.parentElement; n; n = n.parentElement) {
      var role = explicitRole(n);
      if (role === 'grid' || role === 'treegrid') { return true; }
    }
    return false;
  }

  function inputRole(el) {
    var type = el.type;
    if (type === 'hidden') { return null; }
    if (el.hasAttribute('list') && LIST_INPUTS.indexOf(type) >= 0) { return 'combobox'; }
    return has(INPUT_ROLES, type) ? INPUT_ROLES[type] : null;
  }

  function headerRole(el, landmark) {
    var parent = el.parentElement;
    return parent && parent.closest('article, aside, main, nav, section') ? 'generic' : landmark;
  }

  function thRole(el) {
    var scope = (el.getAttribute('scope') || '').toLowerCase();
    if (scope === 'row') { return 'rowheader'; }
    if (scope === 'col') { return 'columnheader'; }
    var first = el.parentElement && el.parentElement.localName === 'tr' && el.cellIndex === 0;
    return first && !el.closest('thead') ? 'rowheader' : 'columnheader';
  }

  function implicitRole(el) {
    var tag = el.localName;
    switch (tag) {
      case 'a': return el.hasAttribute('href') ? 'link' : 'generic';
      case 'area': return el.hasAttribute('href') ? 'link' : 'generic';
      case 'header': return headerRole(el, 'banner');
      case 'footer': return headerRole(el, 'contentinfo');
      case 'img': return el.getAttribute('alt') === '' ? 'presentation' : 'img';
      case 'input': return inputRole(el);
      case 'li': return el.parentElement && /^(ul|ol|menu)$/.test(el.parentElement.localName) ? 'listitem' : 'generic';
      case 'section': return ariaName(el) ? 'region' : 'generic';
      case 'select': return el.multiple || el.size > 1 ? 'listbox' : 'combobox';
      case 'td': return insideGrid(el) ? 'gridcell' : 'cell';
      case 'th': return thRole(el);
      case 'summary': return null;
      default: return has(TAG_ROLES, tag) ? TAG_ROLES[tag] : null;
    }
  }

  function getRole(el) { return explicitRole(el) || implicitRole(el); }

  function hiddenSelf(el) {
    if (el.getAttribute('aria-hidden') === 'true') { return true; }
    if (el.localName === 'input' && el.type === 'hidden') { return true; }
    var style = window.getComputedStyle(el);
    return (style.display === 'none' && el.localName !== 'area') || style.visibility === 'hidden' || style.visibility === 'collapse';
  }

  function isHidden(el) {
    if (el.closest('[aria-hidden="true"]')) { return true; }
    if (el.localName !== 'area' && el.checkVisibility && !el.checkVisibility()) { return true; }
    for (var n = el; n && n.nodeType === 1; n = n.parentElement) {
      if (n.localName !== 'area' && window.getComputedStyle(n).display === 'none') { return true; }
    }
    return hiddenSelf(el);
  }

  function textOfIds(el, attribute) {
    var ids = (el.getAttribute(attribute) || '').split(/\s+/);
    var parts = [];
    for (var i = 0; i < ids.length; i++) {
      var ref = ids[i] ? el.ownerDocument.getElementById(ids[i]) : null;
      if (ref) { parts.push(nameOf(ref, { inRef: true, content: true, ref: true })); }
    }
    return parts.join(' ');
  }

  function ariaName(el) {
    if (el.hasAttribute('aria-labelledby')) {
      var referenced = textOfIds(el, 'aria-labelledby');
      if (normalize(referenced)) { return referenced; }
    }
    var label = el.getAttribute('aria-label');
    return label && normalize(label) ? label : '';
  }

  function selectedText(select) {
    var out = [];
    for (var i = 0; i < select.selectedOptions.length; i++) { out.push(select.selectedOptions[i].textContent); }
    return out.join(' ');
  }

  function embeddedValue(el, role) {
    if (role === 'textbox') { return 'value' in el ? el.value : el.textContent; }
    if (role === 'combobox' || role === 'listbox') {
      if (el.localName === 'select') { return selectedText(el); }
      return 'value' in el ? el.value : '';
    }
    if (role === 'slider' || role === 'spinbutton') {
      return el.getAttribute('aria-valuetext') || el.getAttribute('aria-valuenow') || el.value || '';
    }
    return '';
  }

  function inlineDisplay(el) {
    var display = window.getComputedStyle(el).display;
    return display === 'contents' || display.indexOf('inline') === 0;
  }

  function childrenText(el, o) {
    var out = '';
    for (var n = el.firstChild; n; n = n.nextSibling) {
      if (n.nodeType === 3) {
        out += n.data;
      } else if (n.nodeType === 1) {
        var text = nameOf(n, { inRef: o.inRef, content: true, skip: o.skip, ref: false });
        out += inlineDisplay(n) ? text : ' ' + text + ' ';
      }
    }
    return out;
  }

  function labelsText(el, o) {
    var out = [];
    var labels = el.labels || [];
    for (var i = 0; i < labels.length; i++) {
      out.push(childrenText(labels[i], { inRef: o.inRef, skip: el }));
    }
    return out.join(' ');
  }

  function childElement(el, tag) {
    for (var n = el.firstElementChild; n; n = n.nextElementSibling) {
      if (n.localName === tag) { return n; }
    }
    return null;
  }

  function nativeName(el, o) {
    var tag = el.localName;
    var type = tag === 'input' ? el.type : '';
    var text = '';
    if (type === 'button' || type === 'submit' || type === 'reset') { return el.value || ''; }
    if (tag === 'img' || tag === 'area' || type === 'image') {
      text = el.getAttribute('alt') || '';
    } else if (tag === 'table') {
      text = el.caption ? childrenText(el.caption, { inRef: o.inRef }) : '';
    } else if (tag === 'fieldset' || tag === 'figure') {
      var holder = childElement(el, tag === 'fieldset' ? 'legend' : 'figcaption');
      text = holder ? childrenText(holder, { inRef: o.inRef }) : '';
    } else if (el.labels) {
      text = labelsText(el, o);
    }
    return text;
  }

  // o.top: the element asked about; o.ref: named by aria-labelledby (hidden state ignored);
  // o.inRef: inside a labelledby walk (no second labelledby); o.content: walking a name-from-content subtree.
  function nameOf(el, o) {
    if (el === o.skip) { return ''; }
    if (!o.ref && (o.top ? isHidden(el) : hiddenSelf(el))) { return ''; }
    var role = getRole(el);
    var text = o.inRef ? '' : ariaName(el);
    if (!o.inRef && normalize(text)) { return text; }
    var label = o.inRef ? el.getAttribute('aria-label') : '';
    if (label && normalize(label)) { return label; }
    if (!o.top && normalize(embeddedValue(el, role))) { return embeddedValue(el, role); }
    text = nativeName(el, o);
    if (normalize(text)) { return text; }
    if (o.content || o.top && NAME_FROM_CONTENT.indexOf(role) >= 0) {
      text = childrenText(el, o);
      if (normalize(text)) { return text; }
    }
    return el.getAttribute('title') || '';
  }

  function nameWithin(el, includeHidden) {
    return normalize(nameOf(el, { top: true, ref: includeHidden }));
  }

  function accessibleName(el) { return nameWithin(el, false); }

  function role(scope, wanted, options) {
    var root = scope || document;
    var opts = options || {};
    var named = opts.name !== null && opts.name !== undefined;
    var needle = named ? normalize(opts.name) : '';
    var all = root.querySelectorAll('*');
    var found = [];
    for (var i = 0; i < all.length; i++) {
      var el = all[i];
      if (getRole(el) !== wanted) { continue; }
      if (!opts.includeHidden && isHidden(el)) { continue; }
      if (named) {
        var name = nameWithin(el, opts.includeHidden === true);
        var ok = opts.exact ? name === needle : name.toLowerCase().indexOf(needle.toLowerCase()) >= 0;
        if (!ok) { continue; }
      }
      found.push(el);
    }
    return found;
  }

  window.__raider = window.__raider || {};
  Object.assign(window.__raider, { role: role, getRole: getRole, accessibleName: accessibleName, isHidden: isHidden });
})();
