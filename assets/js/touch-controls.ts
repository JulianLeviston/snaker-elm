// Touch controls for mobile devices - swipe gestures and D-pad overlay

interface TouchPorts {
  receiveTouchDirection: { send: (direction: string) => void };
}

interface SwipeState {
  startX: number;
  startY: number;
  startTime: number;
}

const SWIPE_THRESHOLD = 30; // Minimum distance for swipe detection
const SWIPE_TIME_LIMIT = 300; // Maximum time for swipe gesture (ms)

let swipeState: SwipeState | null = null;
let dpadVisible = true;

export function setupTouchControls(ports: TouchPorts): void {
  // Only setup on touch-capable devices
  if (!("ontouchstart" in window)) {
    return;
  }

  setupSwipeDetection(ports);
  createDpad(ports);

  console.log("Touch controls initialized");
}

function setupSwipeDetection(ports: TouchPorts): void {
  const gameArea = document.body;

  gameArea.addEventListener("touchstart", (e: TouchEvent) => {
    // Don't interfere with D-pad touches
    if ((e.target as HTMLElement).closest(".dpad")) {
      return;
    }

    const touch = e.touches[0];
    swipeState = {
      startX: touch.clientX,
      startY: touch.clientY,
      startTime: Date.now(),
    };
  }, { passive: true });

  gameArea.addEventListener("touchend", (e: TouchEvent) => {
    if (!swipeState) return;

    // Don't process if it was a D-pad touch
    if ((e.target as HTMLElement).closest(".dpad")) {
      swipeState = null;
      return;
    }

    const touch = e.changedTouches[0];
    const deltaX = touch.clientX - swipeState.startX;
    const deltaY = touch.clientY - swipeState.startY;
    const deltaTime = Date.now() - swipeState.startTime;

    // Check if it's a valid swipe
    if (deltaTime < SWIPE_TIME_LIMIT) {
      const absX = Math.abs(deltaX);
      const absY = Math.abs(deltaY);

      if (absX > SWIPE_THRESHOLD || absY > SWIPE_THRESHOLD) {
        let direction: string;

        if (absX > absY) {
          // Horizontal swipe
          direction = deltaX > 0 ? "right" : "left";
        } else {
          // Vertical swipe
          direction = deltaY > 0 ? "down" : "up";
        }

        ports.receiveTouchDirection.send(direction);
      }
    }

    swipeState = null;
  }, { passive: true });

  gameArea.addEventListener("touchcancel", () => {
    swipeState = null;
  }, { passive: true });
}

function createDpad(ports: TouchPorts): void {
  const dpad = document.createElement("div");
  dpad.className = "dpad";
  dpad.innerHTML = `
    <button class="dpad-btn dpad-up" data-direction="up" aria-label="Up">
      <svg viewBox="0 0 24 24" fill="currentColor">
        <path d="M12 4l-8 8h16z"/>
      </svg>
    </button>
    <button class="dpad-btn dpad-left" data-direction="left" aria-label="Left">
      <svg viewBox="0 0 24 24" fill="currentColor">
        <path d="M4 12l8-8v16z"/>
      </svg>
    </button>
    <button class="dpad-btn dpad-right" data-direction="right" aria-label="Right">
      <svg viewBox="0 0 24 24" fill="currentColor">
        <path d="M20 12l-8 8V4z"/>
      </svg>
    </button>
    <button class="dpad-btn dpad-down" data-direction="down" aria-label="Down">
      <svg viewBox="0 0 24 24" fill="currentColor">
        <path d="M12 20l8-8H4z"/>
      </svg>
    </button>
    <button class="dpad-toggle" aria-label="Toggle D-pad">
      <svg viewBox="0 0 24 24" fill="currentColor">
        <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>
      </svg>
    </button>
  `;

  document.body.appendChild(dpad);

  // Handle D-pad button presses
  dpad.querySelectorAll(".dpad-btn").forEach((btn) => {
    const direction = (btn as HTMLElement).dataset.direction;
    if (!direction) return;

    // Use touchstart for immediate response
    btn.addEventListener("touchstart", (e) => {
      e.preventDefault(); // Prevent double-firing and zoom
      ports.receiveTouchDirection.send(direction);
      btn.classList.add("active");
    }, { passive: false });

    btn.addEventListener("touchend", () => {
      btn.classList.remove("active");
    }, { passive: true });

    btn.addEventListener("touchcancel", () => {
      btn.classList.remove("active");
    }, { passive: true });
  });

  // Toggle D-pad visibility
  const toggleBtn = dpad.querySelector(".dpad-toggle");
  if (toggleBtn) {
    toggleBtn.addEventListener("click", () => {
      dpadVisible = !dpadVisible;
      dpad.classList.toggle("dpad-hidden", !dpadVisible);
    });
  }
}
