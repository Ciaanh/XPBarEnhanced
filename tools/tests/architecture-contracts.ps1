$ErrorActionPreference = "Stop"

function Assert-PatternAbsent {
	param(
		[string]$Path,
		[string]$Pattern,
		[string]$Message
	)

	$matches = Select-String -Path $Path -Pattern $Pattern
	if ($matches) {
		Write-Error "$Message`nFound in $Path"
	}
}

function Assert-PatternPresent {
	param(
		[string]$Path,
		[string]$Pattern,
		[string]$Message
	)

	$matches = Select-String -Path $Path -Pattern $Pattern
	if (-not $matches) {
		Write-Error "$Message`nMissing in $Path"
	}
}

Assert-PatternAbsent -Path "core/EventRouter.lua" -Pattern "Addon\.EventBus\.Emit" -Message "EventRouter must not emit internal EventBus events directly."
Assert-PatternAbsent -Path "core/EventRouter.lua" -Pattern "XPBarContextBuilder\.BuildContext" -Message "EventRouter must not build XP render contexts directly."

Assert-PatternAbsent -Path "core/services/ContextBuilder.lua" -Pattern "function\s+XPBarContextBuilder\.BuildReputationContext" -Message "Reputation context must be owned by ReputationSession, not ContextBuilder."
Assert-PatternAbsent -Path "core/services/ReputationSession.lua" -Pattern "XPBarContextBuilder\.BuildReputationContext" -Message "ReputationSession must not depend on ContextBuilder reputation builder."

Assert-PatternPresent -Path "ui/mixins/BaseMixin.lua" -Pattern "BuildTextRefreshContext\(" -Message "BaseMixin ticker should use lightweight text refresh context."

Assert-PatternPresent -Path "core/services/Session.lua" -Pattern "Session:OnXPUpdate\(true\)" -Message "Quest turn-in flow must suppress duplicate XP emit while refreshing baseline."
Assert-PatternPresent -Path "core/services/Session.lua" -Pattern 'Session:EmitUpdate\("QUEST_LOG_UPDATE"\)' -Message "Quest turn-in flow must emit one coalesced quest update."

Assert-PatternAbsent -Path "docs/backlog/README.md" -Pattern "\| \[options-panel-sections\.md\]" -Message "Closed backlog items must be removed from active backlog list."

Write-Host "architecture-contracts.ps1: all checks passed"
