# Charcoal presentation

Shared presentation owner: android-NDK `e8b67dfc67776c2b8da919785d15f38d68c91db0`.
The four resource files and native header are byte-checked against that owner.
The application explicitly uses its fullscreen charcoal theme, independent of
system night mode. Startup windows, framework dialogs and system bars use the
same fixed palette.

The GLES clear becomes neutral #212121. The trajectory, scientific line color, RK4 integration, camera, input and lifecycle are unchanged. The maintained native CI still compiles all application C through ICK on all three ABIs.

`android/link-resources.grease` compiles and links the resource table at the
existing manifest/API boundary. It is invoked by the existing packager through
SPROTT_GREASE, the absolute canonical Grease entrypoint. The short helper
uses Grease because it sequences Android packaging programs; it adds no
application logic or another source generator. Its parse check is separate
from actual aapt2 execution in CI. No Bash business logic is added.

Signing still requires the existing six SPROTT signing inputs, including the expected certificate digest. No replacement signer is generated or borrowed. A maintained signing identity has not been available to this job; a linked library/resource table does not qualify a signed C67 APK.

API29/API34 appearance/state execution and physical C67 acceptance remain
NOT_RUN. Existing host/native compilation and palette-copy checks cannot
establish those results. No installed app or public deployment is changed.

The first run41991829910 passes host semantics and the actual ARMv7 native
library/resource table. ARM64/x86 fail in the old compiler provider before app
compilation because NDK29 rejects its .base64 directive. Promote only the
Android producer to qualified ai-ci f6d825d15cd3c0c34ae1b43240a463ff5d343090,
which pins ICK fbe86e23d55cfec2000c08e61deea2a407fd7175 and qualifies assembler
capability. Host ICK and NDK29 are preserved. Current full qualification is pending.
