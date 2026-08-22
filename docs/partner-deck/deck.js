(function () {
  const slides = [...document.querySelectorAll(".slide")];
  const dots = document.getElementById("dots");
  if (!slides.length || !dots) return;
  let i = 0;
  slides.forEach(() => dots.appendChild(document.createElement("i")));
  function show(n) {
    i = (n + slides.length) % slides.length;
    slides.forEach((s, k) => s.classList.toggle("on", k === i));
    [...dots.children].forEach((d, k) => d.classList.toggle("on", k === i));
    const pos = document.getElementById("pos");
    if (pos) pos.textContent = (i + 1) + " / " + slides.length;
  }
  document.getElementById("prev").onclick = () => show(i - 1);
  document.getElementById("next").onclick = () => show(i + 1);
  document.addEventListener("keydown", (e) => {
    if (e.key === "ArrowRight" || e.key === " ") { e.preventDefault(); show(i + 1); }
    if (e.key === "ArrowLeft") show(i - 1);
    if (e.key === "Home") show(0);
    if (e.key === "End") show(slides.length - 1);
    if (e.key === "f" || e.key === "F") {
      if (!document.fullscreenElement) document.documentElement.requestFullscreen?.();
      else document.exitFullscreen?.();
    }
  });
  let x0 = null;
  document.addEventListener("touchstart", (e) => { x0 = e.changedTouches[0].screenX; });
  document.addEventListener("touchend", (e) => {
    if (x0 == null) return;
    const dx = e.changedTouches[0].screenX - x0;
    if (dx < -40) show(i + 1);
    if (dx > 40) show(i - 1);
    x0 = null;
  });
  show(0);
})();
