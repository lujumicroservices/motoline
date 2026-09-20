(function () {
  const cfg = window.RAWTHROTTLE || {};
  const salesOpen = Boolean(cfg.salesOpen);
  const wa = String(cfg.whatsapp || "").replace(/\D/g, "");
  const products = cfg.products || [];
  const imgBase = "img/products/";

  function money(n) {
    if (!n) return "Próximamente";
    return new Intl.NumberFormat("es-MX", {
      style: "currency",
      currency: cfg.currency || "MXN",
      maximumFractionDigits: 0,
    }).format(n);
  }

  function waLink(text) {
    return "https://wa.me/" + wa + "?text=" + encodeURIComponent(text);
  }

  function shipFor(product) {
    return product.category === "gorra" ? cfg.shipping.hatEstafeta : cfg.shipping.teeEstafeta;
  }

  function setText(id, value) {
    const el = document.getElementById(id);
    if (el) el.textContent = value;
  }

  function fillSelect(el, sizes) {
    el.innerHTML = (sizes || [])
      .map(function (s) {
        return '<option value="' + s + '">' + s + "</option>";
      })
      .join("");
  }

  const market = document.getElementById("market");
  const modal = document.getElementById("modal");
  let active = null;
  let filter = "all";

  function matches(p) {
    if (filter === "all") return true;
    if (filter === "playera" || filter === "gorra") return p.category === filter;
    return p.brand === filter;
  }

  function renderGrid() {
    market.innerHTML = products
      .filter(matches)
      .map(function (p) {
        const thumb = imgBase + (p.thumbs && p.thumbs[0] ? p.thumbs[0] : p.images[0]);
        return (
          '<button class="sku" type="button" data-id="' +
          p.id +
          '">' +
          '<img src="' +
          thumb +
          '" alt="' +
          p.name +
          '" />' +
          '<div class="sku-body">' +
          '<div class="sku-brand">' +
          p.brand +
          " · " +
          p.category +
          "</div>" +
          "<h3>" +
          p.name +
          "</h3>" +
          '<p class="price">' +
          money(p.price) +
          "</p>" +
          "</div></button>"
        );
      })
      .join("");
  }

  function showPhoto(p, index) {
    const photo = document.getElementById("modal-photo");
    photo.src = imgBase + p.images[index];
    photo.alt = p.name;
    document.querySelectorAll("#modal-thumbs button").forEach(function (b, i) {
      b.classList.toggle("on", i === index);
    });
  }

  function openProduct(id) {
    const p = products.find(function (x) {
      return x.id === id;
    });
    if (!p) return;
    active = p;
    document.getElementById("modal-brand").textContent = p.brand;
    document.getElementById("modal-title").textContent = p.name;
    document.getElementById("modal-price").textContent = money(p.price);
    document.getElementById("modal-blurb").textContent = p.blurb;
    fillSelect(document.getElementById("modal-size"), p.sizes);
    const thumbs = document.getElementById("modal-thumbs");
    thumbs.innerHTML = p.images
      .map(function (src, i) {
        const t = p.thumbs && p.thumbs[i] ? p.thumbs[i] : src;
        return (
          '<button type="button" data-i="' +
          i +
          '"><img src="' +
          imgBase +
          t +
          '" alt=""></button>'
        );
      })
      .join("");
    showPhoto(p, 0);
    modal.hidden = false;
    modal.classList.add("open");
    document.body.classList.add("locked");
  }

  function closeModal() {
    modal.classList.remove("open");
    modal.hidden = true;
    document.body.classList.remove("locked");
    active = null;
  }

  market.addEventListener("click", function (e) {
    const sku = e.target.closest(".sku");
    if (sku) openProduct(sku.getAttribute("data-id"));
  });

  document.getElementById("modal-thumbs").addEventListener("click", function (e) {
    const btn = e.target.closest("button");
    if (btn && active) showPhoto(active, Number(btn.getAttribute("data-i")));
  });

  document.getElementById("modal-close").addEventListener("click", closeModal);
  modal.addEventListener("click", function (e) {
    if (e.target === modal) closeModal();
  });
  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape") closeModal();
  });

  document.getElementById("modal-buy").addEventListener("click", function () {
    if (!salesOpen || !active || !wa) return;
    const size = document.getElementById("modal-size").value;
    const ship = shipFor(active);
    const total = active.price + ship;
    const msg =
      "Quiero la " +
      active.name +
      " talla " +
      size +
      ". Van " +
      money(active.price) +
      " + envío " +
      money(ship) +
      " (total " +
      money(total) +
      "). Mi CP es: ";
    window.open(waLink(msg), "_blank", "noopener");
  });

  if (!salesOpen) {
    const buy = document.getElementById("modal-buy");
    if (buy) {
      buy.textContent = "Venta lista pronto";
      buy.disabled = true;
      buy.classList.add("is-off");
    }
  }

  if (!wa) {
    document.querySelectorAll("[data-wa], a[href='#contacto']").forEach(function (el) {
      el.classList.add("hidden");
    });
    const buy = document.getElementById("modal-buy");
    if (buy && salesOpen) buy.classList.add("hidden");
    const contact = document.getElementById("contacto");
    if (contact) contact.classList.add("hidden");
  } else {
    document.querySelectorAll("[data-wa]").forEach(function (el) {
      el.href = waLink(el.getAttribute("data-wa") || "Hola, vengo de rawthrottle.com.mx");
    });
  }

  document.querySelectorAll(".filter").forEach(function (btn) {
    btn.addEventListener("click", function () {
      document.querySelectorAll(".filter").forEach(function (b) {
        b.classList.remove("on");
      });
      btn.classList.add("on");
      filter = btn.getAttribute("data-filter");
      renderGrid();
    });
  });

  setText("tee-ship", money(cfg.shipping.teeEstafeta));
  setText("tee-ship-copy", money(cfg.shipping.teeEstafeta));
  setText("origin-city", cfg.originCity || "México");

  renderGrid();
})();
