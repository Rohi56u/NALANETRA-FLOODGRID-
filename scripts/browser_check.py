"""Exercise the real review UI with three isolated roles and labelled synthetic captures."""

import json
import os
from pathlib import Path
import socket
import tempfile
import threading
import time
from PIL import Image, ImageDraw
from playwright.sync_api import sync_playwright
import uvicorn
from backend.main import create_app
from backend.settings import Settings
from scripts.bootstrap_demo import seed_accounts, DEMO_PASSWORD

ROOT = Path(__file__).resolve().parents[1]


def submit_action(page, selector, endpoint, status=200):
    """Wait for the real write acknowledgment before inspecting refreshed state."""
    with page.expect_response(
        lambda response: (
            response.request.method == "POST"
            and response.url.endswith(f"/api/v1{endpoint}")
        )
    ) as pending:
        page.locator(selector).click()
    response = pending.value
    assert response.status == status, f"{endpoint}: {response.status} {response.text()}"
    return response.json()


def make_photo(path, stage):
    image = Image.new("RGB", (900, 500), (40, 55, 72))
    draw = ImageDraw.Draw(image)
    draw.rectangle(
        (0, 245, 900, 500), fill=(161, 122, 64) if stage != 2 else (112, 119, 126)
    )
    draw.rectangle((70 + stage * 80, 90, 400 + stage * 80, 245), fill=(207, 218, 229))
    draw.line(
        (0, 490 - stage * 55, 900, 350 - stage * 55), fill=(239, 193, 97), width=12
    )
    draw.text((30, 25), f"SYNTHETIC LOCAL TEST CAPTURE · stage {stage}", fill="white")
    image.save(path)


def main():
    with tempfile.TemporaryDirectory(prefix="nalanetra-ui-check-") as temporary:
        directory = Path(temporary)
        config = Settings(
            data_dir=directory / "data",
            mode="test",
            jwt_secret="private-test-session-secret-at-least-32-chars",
        ).prepare()
        seed_accounts(config)
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        server = uvicorn.Server(
            uvicorn.Config(
                create_app(config), host="127.0.0.1", port=port, log_level="error"
            )
        )
        thread = threading.Thread(target=server.run, daemon=True)
        thread.start()
        deadline = time.monotonic() + 10
        while not server.started:
            if time.monotonic() > deadline:
                raise RuntimeError("Local review service did not start")
            threading.Event().wait(0.05)
        for stage in range(3):
            make_photo(directory / f"photo-{stage}.png", stage)
        errors = []
        try:
            with sync_playwright() as driver:
                browser = driver.chromium.launch(
                    headless=True,
                    executable_path=os.getenv("NALA_BROWSER_BINARY") or None,
                    args=["--no-sandbox", "--disable-dev-shm-usage"],
                )
                pages = {}
                for role in ["citizen", "officer", "crew"]:
                    page = browser.new_page(
                        viewport={"width": 1440, "height": 1100}, device_scale_factor=1
                    )
                    page.on("pageerror", lambda error: errors.append(str(error)))
                    page.goto(f"http://127.0.0.1:{port}", wait_until="networkidle")
                    page.locator("#login select[name=role]").select_option(role)
                    page.locator("#login input[name=email]").fill(
                        f"{role}@example.test"
                    )
                    page.locator("#login input[name=staffId]").fill(
                        {"officer": "MCG-OF-001", "crew": "MCG-FC-001"}.get(role, "")
                    )
                    page.locator("#login input[name=password]").fill(DEMO_PASSWORD)
                    submit_action(page, "#login button", "/auth/login")
                    page.locator("#workspace").wait_for()
                    pages[role] = page
                citizen = pages["citizen"]
                citizen.locator("#report input[name=location]").fill(
                    "Synthetic review site · local demo"
                )
                citizen.locator("#report select[name=depth_tag]").select_option("knee")
                citizen.locator("#report input[name=photo]").set_input_files(
                    directory / "photo-0.png"
                )
                citizen.locator("#report textarea").fill(
                    "Synthetic demo intake; no field measurement."
                )
                invalid_fields = citizen.locator("#report").evaluate(
                    "form => [...form.elements].filter(e => e.willValidate && !e.checkValidity()).map(e => ({name:e.name, error:e.validationMessage}))"
                )
                assert not invalid_fields, invalid_fields
                receipt = submit_action(
                    citizen, "#report button", "/incidents/report", 201
                )
                identifier = receipt["incident_id"]
                assert receipt["report_id"] and identifier
                citizen.locator("#detail .status").wait_for()
                officer = pages["officer"]
                officer.locator("#refresh").click()
                officer.locator("#review").wait_for()
                officer.locator("#review input[name=rain_mm_hr]").fill("40")
                officer.locator("#review input[name=ward_criticality]").fill("0.5")
                officer.locator("#review input[name=blockage]").fill("0.5")
                officer.locator("#review input[name=emergency_route]").check()
                officer.locator("#review input[type=checkbox]").last.check()
                officer.locator("#review textarea").fill(
                    "Synthetic fixture context only. Officer checks photo, depth tag and source note."
                )
                submit_action(
                    officer,
                    "#review button:first-of-type",
                    f"/incidents/{identifier}/review",
                )
                officer.locator("#dispatch").wait_for()
                submit_action(
                    officer, "#dispatch button", f"/incidents/{identifier}/dispatch"
                )
                officer.wait_for_function(
                    "document.querySelector('#detail .status')?.textContent==='DISPATCHED'"
                )
                crew = pages["crew"]
                crew.locator("#refresh").click()
                crew.locator("#onsite").wait_for()
                submit_action(crew, "#onsite", f"/jobs/{identifier}/status")
                crew.locator("#proofForm").wait_for()
                crew.locator("#proofForm input[name=photo]").set_input_files(
                    directory / "photo-1.png"
                )
                crew.locator("#proofForm textarea").fill(
                    "Synthetic before-work capture."
                )
                submit_action(
                    crew, "#proofForm button", f"/jobs/{identifier}/evidence", 201
                )
                crew.wait_for_function(
                    "document.querySelector('#proofForm label')?.textContent.includes('After')"
                )
                crew.locator("#proofForm input[name=photo]").set_input_files(
                    directory / "photo-2.png"
                )
                crew.locator("#proofForm textarea").fill(
                    "Synthetic after-cleanup capture; officer review required."
                )
                submit_action(
                    crew, "#proofForm button", f"/jobs/{identifier}/evidence", 201
                )
                crew.wait_for_function(
                    "document.querySelector('#detail .status')?.textContent==='AWAITING REVIEW'"
                )
                officer.locator("#refresh").click()
                officer.locator("#approve").wait_for()
                officer.locator("#closureNote").fill(
                    "Compared synthetic before/after pair and recorded fixture capture metadata."
                )
                submit_action(officer, "#approve", f"/incidents/{identifier}/closure")
                officer.wait_for_function(
                    "document.querySelector('#detail .status')?.textContent==='CLOSED'"
                )
                officer.locator("#risk").click()
                officer.locator("#riskChart svg").wait_for()
                for page in pages.values():
                    page.locator("#refresh").click()
                    page.wait_for_function(
                        "document.querySelector('#detail .status')?.textContent==='CLOSED'"
                    )
                    page.wait_for_function(
                        "[...document.querySelectorAll('#detail img')].every(i=>i.complete&&i.naturalWidth>0)"
                    )
                    assert not page.locator("#error").is_visible()
                assert not errors, errors
                (ROOT / "docs/assets").mkdir(exist_ok=True)
                officer.screenshot(
                    path=str(ROOT / "docs/assets/review_console.png"), full_page=True
                )
                officer.set_viewport_size({"width": 390, "height": 844})
                assert officer.evaluate(
                    "document.documentElement.scrollWidth<=window.innerWidth"
                )
                officer.screenshot(
                    path=str(ROOT / "docs/assets/review_console_mobile.png"),
                    full_page=True,
                )
                state = officer.evaluate("snapshot")
                summary = {
                    "source": "Synthetic local browser exercise",
                    "browser": "Chromium",
                    "roles_checked": 3,
                    "closed_incidents": sum(
                        i["status"] == "CLOSED" for i in state["incidents"]
                    ),
                    "distinct_evidence_records": len(state["evidence"]),
                    "page_errors": errors,
                    "mobile_horizontal_overflow": False,
                    "workflow": "Citizen report → Officer review → Dispatch → GPS fixture arrival → Before/after proof → Officer closure",
                    "screenshot": "docs/assets/review_console.png",
                }
                (ROOT / "data/demo/browser_check.json").write_text(
                    json.dumps(summary, indent=2) + "\n"
                )
                browser.close()
        finally:
            server.should_exit = True
            thread.join(timeout=5)
    print(
        "Passed: three UI roles, officer closure, distinct protected photos, risk chart and 390 px mobile width."
    )


if __name__ == "__main__":
    main()
