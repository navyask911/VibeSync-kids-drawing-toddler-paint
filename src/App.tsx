/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState } from 'react';
import { 
  Smartphone, 
  FileCode, 
  Download, 
  CheckCircle, 
  Columns, 
  Maximize2,
  ShieldCheck,
  Terminal,
  Activity,
  Layers,
  Sparkles
} from 'lucide-react';
import { DeveloperConversationPanel } from './components/DeveloperConversationPanel';
import { LivePreviewStage } from './components/LivePreviewStage';
import { ParentalGateModal } from './components/ParentalGateModal';
import { AdMobSimulatorModal } from './components/AdMobSimulatorModal';
import { 
  AdMobConfig, 
  GOOGLE_TEST_IDS, 
  PRODUCTION_CONFIG,
  generateAdHelperDart, 
  generateMainDart, 
  generateAndroidManifestXml, 
  generatePubspecYaml, 
  generateCOPPAComplianceChecklist,
  generateBuildGradle,
  generateProguardRules,
  generateKeyPropertiesExample,
  generateGitignore,
  generateAdMobUnitTestDart,
  generateMainActivityKt
} from './data/flutterCode';

export default function App() {
  const [config, setConfig] = useState<AdMobConfig>(PRODUCTION_CONFIG);
  const [isUsingTestIds, setIsUsingTestIds] = useState<boolean>(false);
  const [activeRightTab, setActiveRightTab] = useState<'simulator' | 'code' | 'guide' | 'logs' | 'tests'>('tests');
  const [viewMode, setViewMode] = useState<'split' | 'conversation' | 'preview'>('split');

  // Drawing active sentinel state
  const [isDrawingActive, setIsDrawingActive] = useState<boolean>(false);

  // Unlocked bonus coloring pages
  const [unlockedPages, setUnlockedPages] = useState<Set<string>>(
    new Set<string>(['Cosmic Rocket']) // Initial bonus unlocked
  );

  // Parental Gate Modal State
  const [parentalGateOpen, setParentalGateOpen] = useState<boolean>(false);
  const [targetBonusPage, setTargetBonusPage] = useState<string>('');
  const [targetAdFormat, setTargetAdFormat] = useState<'Rewarded Video Ad' | 'Interstitial Ad'>('Rewarded Video Ad');

  // AdMob Video Simulator Modal State
  const [adSimulatorOpen, setAdSimulatorOpen] = useState<boolean>(false);
  const [adSimulatorType, setAdSimulatorType] = useState<'rewarded' | 'interstitial'>('rewarded');

  // These are clearly labelled demo entries. This browser dashboard does not
  // connect to the installed Flutter app or verify live AdMob serving.
  const [adLogs, setAdLogs] = useState<Array<{ id: string; time: string; text: string; type: 'info' | 'success' | 'warn' }>>([
    {
      id: 'l1',
      time: '11:16:00',
      text: 'Demo configuration example loaded; live AdMob app initialization has not been checked.',
      type: 'info',
    },
    {
      id: 'l2',
      time: '11:16:01',
      text: 'Example banner unit ID is displayed for review only; live ad serving is not verified by this dashboard.',
      type: 'info',
    },
    {
      id: 'l3',
      time: '11:16:02',
      text: 'Child-directed request flags are code examples only. Verify actual SDK behavior, consent, disclosures, and ad formats before release.',
      type: 'info',
    },
  ]);

  // Toast Notification
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  const addLog = (text: string, type: 'info' | 'success' | 'warn' = 'info') => {
    const time = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
    setAdLogs((prev) => [{ id: `log-${Date.now()}-${Math.random()}`, time, text, type }, ...prev.slice(0, 40)]);
  };

  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 3500);
  };

  const handleRequestUnlock = (pageName: string, adFormat: 'Rewarded Video Ad' | 'Interstitial Ad') => {
    addLog(`User requested bonus page: "${pageName}". Opening Parental Gate challenge.`, 'info');
    setTargetBonusPage(pageName);
    setTargetAdFormat(adFormat);
    setParentalGateOpen(true);
  };

  const handleParentalGateSuccess = () => {
    addLog(`Parental Gate arithmetic verified by adult. Preparing child-safe ${targetAdFormat}.`, 'success');
    setParentalGateOpen(false);
    setAdSimulatorType(targetAdFormat === 'Rewarded Video Ad' ? 'rewarded' : 'interstitial');
    setAdSimulatorOpen(true);
  };

  const handleRewardEarned = () => {
    if (targetBonusPage) {
      setUnlockedPages((prev) => new Set([...prev, targetBonusPage]));
      addLog(`Reward granted! "${targetBonusPage}" is now unlocked for child canvas.`, 'success');
      showToast(`🎉 "${targetBonusPage}" unlocked! Ready on your toddler drawing pad.`);
    }
  };

  const handleDirectInterstitial = (isDrawing: boolean) => {
    if (isDrawing) {
      addLog('Interstitial ad presentation BLOCKED: active drawing stroke in progress.', 'warn');
      showToast('⚠️ Interstitial ad suppressed! Google Play policy forbids interrupting active child drawings.');
      return;
    }
    addLog('Interstitial ad presentation ALLOWED: canvas is idle.', 'info');
    setTargetBonusPage('Page Transition Ad');
    setAdSimulatorType('interstitial');
    setAdSimulatorOpen(true);
  };

  const handleDrawingStateChange = (active: boolean) => {
    setIsDrawingActive(active);
    if (active) {
      addLog('Canvas pointerdown: isDrawingActive = true (Ad pop-ups suppressed)', 'warn');
    } else {
      addLog('Canvas pointerup: isDrawingActive = false (Canvas idle)', 'info');
    }
  };

  const handleExportAllFiles = () => {
    const files = [
      { name: 'ad_helper.dart', content: generateAdHelperDart(config, isUsingTestIds) },
      { name: 'main.dart', content: generateMainDart() },
      { name: 'MainActivity.kt', content: generateMainActivityKt() },
      { name: 'AndroidManifest.xml', content: generateAndroidManifestXml(config.androidAppId) },
      { name: 'build.gradle', content: generateBuildGradle() },
      { name: 'proguard-rules.pro', content: generateProguardRules() },
      { name: 'key.properties.example', content: generateKeyPropertiesExample() },
      { name: 'pubspec.yaml', content: generatePubspecYaml() },
      { name: '.gitignore', content: generateGitignore() },
      { name: 'admob_coppa_test.dart', content: generateAdMobUnitTestDart() },
      { name: 'COPPA_CHECKLIST.md', content: generateCOPPAComplianceChecklist() },
    ];

    files.forEach((file, index) => {
      setTimeout(() => {
        const blob = new Blob([file.content], { type: 'text/plain;charset=utf-8' });
        const url = URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = file.name;
        link.click();
        URL.revokeObjectURL(url);
      }, index * 150);
    });

    addLog('Exported all 11 Flutter production release deliverables (v2 embedding, Dart, Gradle, Proguard, Keystore template, Tests).', 'success');
    showToast('📦 Exported 11 production release files successfully!');
  };

  return (
    <div className="flex flex-col h-screen w-screen overflow-hidden bg-slate-950 font-sans antialiased">
      {/* ------------------------------------------------------------------ */}
      {/* Top Workspace Bar: Clean Minimalist SaaS + Dev Utility             */}
      {/* ------------------------------------------------------------------ */}
      <header className="h-14 bg-[#FFFFFF] border-b border-[#E0E2E6] px-5 flex items-center justify-between z-30 shrink-0 select-none">
        {/* Left Brand & File Context */}
        <div className="flex items-center gap-3">
          <div className="w-8 h-8 rounded-xl bg-gradient-to-tr from-blue-600 via-indigo-600 to-purple-600 flex items-center justify-center text-white shadow-xs">
            <Smartphone className="w-4 h-4" />
          </div>
          <div className="flex items-center gap-2">
            <span className="text-sm font-semibold text-slate-900 tracking-tight">
              Flutter AdMob Kids Studio
            </span>
            <span className="hidden sm:inline-block text-[11px] font-mono text-slate-400 bg-slate-100 px-2 py-0.5 rounded-md border border-slate-200">
              lib/ad_helper.dart
            </span>
          </div>
        </div>

        {/* Center Policy Badges */}
        <div className="hidden md:flex items-center gap-2 text-xs">
          <span className="flex items-center gap-1 px-2.5 py-1 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200 font-medium text-[11px]">
            <ShieldCheck className="w-3.5 h-3.5 text-emerald-600" />
            COPPA Child-Directed (YES)
          </span>
          <span className="flex items-center gap-1 px-2.5 py-1 rounded-full bg-blue-50 text-blue-700 border border-blue-200 font-medium text-[11px]">
            MaxRating: G
          </span>
          <span className="flex items-center gap-1 px-2.5 py-1 rounded-full bg-purple-50 text-purple-700 border border-purple-200 font-medium text-[11px]">
            NPA Active
          </span>
        </div>

        {/* Right Controls: View Splitter & Export */}
        <div className="flex items-center gap-2">
          {/* Split Mode Switcher */}
          <div className="hidden lg:flex items-center bg-[#F1F3F4] p-0.5 rounded-xl border border-[#E0E2E6] text-xs">
            <button
              onClick={() => setViewMode('split')}
              className={`px-2.5 py-1 rounded-lg font-medium transition-all cursor-pointer ${
                viewMode === 'split' ? 'bg-white text-slate-900 shadow-xs' : 'text-slate-600 hover:text-slate-900'
              }`}
              title="Dual-Pane Split (Conversation + Live Stage)"
            >
              <Columns className="w-3.5 h-3.5 inline mr-1 text-blue-600" />
              Dual-Pane
            </button>
            <button
              onClick={() => setViewMode('conversation')}
              className={`px-2.5 py-1 rounded-lg font-medium transition-all cursor-pointer ${
                viewMode === 'conversation' ? 'bg-white text-slate-900 shadow-xs' : 'text-slate-600 hover:text-slate-900'
              }`}
              title="Full Conversation View"
            >
              Chat Focus
            </button>
            <button
              onClick={() => setViewMode('preview')}
              className={`px-2.5 py-1 rounded-lg font-medium transition-all cursor-pointer ${
                viewMode === 'preview' ? 'bg-white text-slate-900 shadow-xs' : 'text-slate-600 hover:text-slate-900'
              }`}
              title="Full Live Stage View"
            >
              Stage Focus
            </button>
          </div>

          <button
            onClick={handleExportAllFiles}
            className="px-3 py-1.5 rounded-xl bg-blue-600 hover:bg-blue-500 text-white text-xs font-semibold shadow-xs flex items-center gap-1.5 transition-all active:scale-95 cursor-pointer whitespace-nowrap"
          >
            <Download className="w-3.5 h-3.5" />
            <span>Export Code</span>
          </button>
        </div>
      </header>

      {/* Toast Alert */}
      {toastMessage && (
        <div className="fixed top-16 right-6 z-50 bg-emerald-600 text-white text-xs font-bold px-4 py-2.5 rounded-2xl shadow-xl flex items-center gap-2 animate-bounce">
          <CheckCircle className="w-4 h-4" />
          <span>{toastMessage}</span>
        </div>
      )}

      {/* ------------------------------------------------------------------ */}
      {/* Main Dual-Pane Workspace Container                                 */}
      {/* ------------------------------------------------------------------ */}
      <div className="flex-1 flex flex-col lg:flex-row overflow-hidden">
        {/* Left Conversation Panel (Light Mode) */}
        {(viewMode === 'split' || viewMode === 'conversation') && (
          <div
            className={`transition-all duration-300 h-full ${
              viewMode === 'conversation'
                ? 'w-full'
                : viewMode === 'split'
                ? 'w-full lg:w-[480px] xl:w-[520px] shrink-0'
                : 'hidden'
            }`}
          >
            <DeveloperConversationPanel
              config={config}
              onUpdateConfig={(c) => {
                setConfig(c);
                addLog('AdMob identifiers updated in AdHelper singleton configuration.', 'info');
              }}
              isUsingTestIds={isUsingTestIds}
              onToggleTestIds={(val) => {
                setIsUsingTestIds(val);
                if (val) setConfig(GOOGLE_TEST_IDS);
                addLog(`Switched AdMob mode: ${val ? 'Official Google Test IDs' : 'Custom Live Production IDs'}`, 'info');
              }}
              onTriggerParentalGate={() => {
                setTargetBonusPage('Magic Unicorn');
                setTargetAdFormat('Rewarded Video Ad');
                setParentalGateOpen(true);
              }}
              onTriggerInterstitialTest={() => handleDirectInterstitial(isDrawingActive)}
              onSwitchRightTab={setActiveRightTab}
              activeRightTab={activeRightTab}
              isDrawingActive={isDrawingActive}
              adLogs={adLogs}
            />
          </div>
        )}

        {/* Right Live Preview Stage (Deep Navy-Slate Dark Mode) */}
        {(viewMode === 'split' || viewMode === 'preview') && (
          <div className="flex-1 h-full min-w-0 overflow-hidden">
            <LivePreviewStage
              config={config}
              onUpdateConfig={(c) => {
                setConfig(c);
                addLog('AdMob identifiers updated.', 'info');
              }}
              isUsingTestIds={isUsingTestIds}
              onToggleTestIds={(val) => {
                setIsUsingTestIds(val);
                if (val) setConfig(GOOGLE_TEST_IDS);
                addLog(`AdMob ID mode changed: ${val ? 'Test' : 'Production'}`, 'info');
              }}
              unlockedPages={unlockedPages}
              onRequestUnlock={handleRequestUnlock}
              onShowInterstitialDirectly={handleDirectInterstitial}
              activeTab={activeRightTab}
              onTabChange={setActiveRightTab}
              isDrawingActive={isDrawingActive}
              onDrawingStateChange={handleDrawingStateChange}
              adLogs={adLogs}
            />
          </div>
        )}
      </div>

      {/* Global Modals: Parental Gate and AdMob Video Simulator */}
      <ParentalGateModal
        isOpen={parentalGateOpen}
        onClose={() => setParentalGateOpen(false)}
        onVerified={handleParentalGateSuccess}
        targetContentName={targetBonusPage}
        adFormatName={targetAdFormat}
      />

      <AdMobSimulatorModal
        isOpen={adSimulatorOpen}
        adType={adSimulatorType}
        adUnitId={
          adSimulatorType === 'rewarded'
            ? config.androidRewardedUnitId
            : config.androidInterstitialUnitId
        }
        config={config}
        targetRewardItemName={targetBonusPage || 'Page Transition Ad'}
        onAdClosed={() => setAdSimulatorOpen(false)}
        onRewardEarned={handleRewardEarned}
      />
    </div>
  );
}
