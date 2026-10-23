import React, { useState } from 'react';
import { 
  Smartphone, 
  Monitor, 
  FileCode, 
  ShieldCheck, 
  Activity, 
  Sparkles, 
  Layers, 
  RefreshCw,
  Terminal,
  ExternalLink,
  Sliders,
  CheckCircle2,
  AlertTriangle,
  Play,
  RotateCw,
  XCircle,
  FileCheck
} from 'lucide-react';
import { KidsDrawingStudio } from './KidsDrawingStudio';
import { FlutterCodeViewer } from './FlutterCodeViewer';
import { PolicyBadgeGuide } from './PolicyBadgeGuide';
import { AdMobConfig } from '../data/flutterCode';

interface LivePreviewStageProps {
  config: AdMobConfig;
  onUpdateConfig: (config: AdMobConfig) => void;
  isUsingTestIds: boolean;
  onToggleTestIds: (val: boolean) => void;
  unlockedPages: Set<string>;
  onRequestUnlock: (pageName: string, adFormat: 'Rewarded Video Ad' | 'Interstitial Ad') => void;
  onShowInterstitialDirectly: (isDrawing: boolean) => void;
  activeTab: 'simulator' | 'code' | 'guide' | 'logs' | 'tests';
  onTabChange: (tab: 'simulator' | 'code' | 'guide' | 'logs' | 'tests') => void;
  isDrawingActive: boolean;
  onDrawingStateChange: (active: boolean) => void;
  adLogs: Array<{ id: string; time: string; text: string; type: 'info' | 'success' | 'warn' }>;
}

export const LivePreviewStage: React.FC<LivePreviewStageProps> = ({
  config,
  onUpdateConfig,
  isUsingTestIds,
  onToggleTestIds,
  unlockedPages,
  onRequestUnlock,
  onShowInterstitialDirectly,
  activeTab,
  onTabChange,
  isDrawingActive,
  adLogs,
}) => {
  const [deviceViewport, setDeviceViewport] = useState<'mobile' | 'tablet'>('mobile');
  const [isRunningTests, setIsRunningTests] = useState<boolean>(false);
  const [testRunTimestamp, setTestRunTimestamp] = useState<string>('Just now');

  const unitTestCases = [
    {
      group: '1. Parental Gate Math Challenge Logic',
      tests: [
        {
          id: 't1',
          name: 'Correct arithmetic solution passes adult verification',
          detail: 'assert(verifyParentalGate(7 + 5 == 12) == true)',
          status: 'passed',
          duration: '12ms',
        },
        {
          id: 't2',
          name: 'Incorrect solution triggers retry and prevents ad impression',
          detail: 'assert(verifyParentalGate(10) == false && adShown == false)',
          status: 'passed',
          duration: '8ms',
        },
        {
          id: 't3',
          name: 'Challenge generator produces randomized positive integer options',
          detail: 'options.length == 4 && options.every(val > 0)',
          status: 'passed',
          duration: '15ms',
        },
      ],
    },
    {
      group: '2. AdHelper Singleton & Stroke Suppression Guard',
      tests: [
        {
          id: 't4',
          name: 'AdHelper enforces single runtime instance',
          detail: 'identical(AdHelper.instance, AdHelper.instance) == true',
          status: 'passed',
          duration: '4ms',
        },
        {
          id: 't5',
          name: 'Active drawing stroke strictly suppresses interstitial ads',
          detail: 'showInterstitialAd(isDrawingActive: true) -> invokes onAdSuppressed()',
          status: 'passed',
          duration: '18ms',
        },
        {
          id: 't6',
          name: 'Canvas idle state permits clean transitions',
          detail: 'showInterstitialAd(isDrawingActive: false) -> invokes onAdPresented()',
          status: 'passed',
          duration: '14ms',
        },
      ],
    },
    {
      group: '3. NPA & COPPA AdRequest Parameters',
      tests: [
        {
          id: 't7',
          name: 'buildChildSafeAdRequest enforces npa == "1"',
          detail: 'request.extras["npa"] == "1" (Zero behavioral profiling)',
          status: 'passed',
          duration: '6ms',
        },
        {
          id: 't8',
          name: 'Global RequestConfiguration COPPA & G-Rating ceiling',
          detail: 'tagForChildDirectedTreatment.yes && maxAdContentRating.g',
          status: 'passed',
          duration: '9ms',
        },
        {
          id: 't9',
          name: 'Production AdMob IDs match verified format',
          detail: 'AndroidManifest.xml metadata & bannerAdUnitId verified',
          status: 'passed',
          duration: '11ms',
        },
      ],
    },
    {
      group: '4. Release Build, Signing & ProGuard Validation',
      tests: [
        {
          id: 't10',
          name: 'android/app/build.gradle wires key.properties release signature',
          detail: 'signingConfigs.release { keyAlias, keyPassword, storeFile, storePassword }',
          status: 'passed',
          duration: '22ms',
        },
        {
          id: 't11',
          name: 'ProGuard rules preserve Google Mobile Ads classes and reflection',
          detail: '-keep class com.google.android.gms.ads.** { *; } verified',
          status: 'passed',
          duration: '19ms',
        },
        {
          id: 't12',
          name: 'flutter_launcher_icons configured for standard and adaptive mipmaps',
          detail: 'adaptive_icon_background and mipmap-hdpi, xhdpi, xxhdpi, xxxhdpi valid',
          status: 'passed',
          duration: '10ms',
        },
      ],
    },
  ];

  const handleRerunTests = () => {
    setIsRunningTests(true);
    setTimeout(() => {
      setIsRunningTests(false);
      setTestRunTimestamp(new Date().toLocaleTimeString());
    }, 700);
  };

  return (
    <div className="flex flex-col h-full bg-[#0A0F1D] text-slate-100 select-none overflow-hidden">
      {/* 1. Stage Glassmorphic Header */}
      <div className="px-6 py-3.5 bg-[#0D1527]/90 backdrop-blur-md border-b border-white/10 flex flex-wrap items-center justify-between gap-4">
        {/* Navigation Tabs */}
        <div className="flex items-center gap-1.5 p-1 bg-slate-900/90 rounded-2xl border border-white/10 text-xs overflow-x-auto">
          <button
            onClick={() => onTabChange('simulator')}
            className={`px-3.5 py-1.5 rounded-xl font-medium flex items-center gap-1.5 transition-all cursor-pointer whitespace-nowrap ${
              activeTab === 'simulator'
                ? 'bg-blue-600 text-white shadow-sm shadow-blue-500/30'
                : 'text-slate-400 hover:text-white'
            }`}
          >
            <Smartphone className="w-3.5 h-3.5" />
            <span>Flutter App Live</span>
          </button>

          <button
            onClick={() => onTabChange('code')}
            className={`px-3.5 py-1.5 rounded-xl font-medium flex items-center gap-1.5 transition-all cursor-pointer whitespace-nowrap ${
              activeTab === 'code'
                ? 'bg-blue-600 text-white shadow-sm shadow-blue-500/30'
                : 'text-slate-400 hover:text-white'
            }`}
          >
            <FileCode className="w-3.5 h-3.5" />
            <span>Dart Code & Release</span>
          </button>

          <button
            onClick={() => onTabChange('tests')}
            className={`px-3.5 py-1.5 rounded-xl font-medium flex items-center gap-1.5 transition-all cursor-pointer whitespace-nowrap ${
              activeTab === 'tests'
                ? 'bg-emerald-600 text-white shadow-sm shadow-emerald-500/30'
                : 'text-slate-400 hover:text-white'
            }`}
          >
            <FileCheck className="w-3.5 h-3.5 text-emerald-400" />
            <span>Unit & COPPA Tests</span>
            <span className="text-[10px] bg-emerald-500/30 px-1.5 py-0.2 rounded font-mono">12/12</span>
          </button>

          <button
            onClick={() => onTabChange('guide')}
            className={`px-3.5 py-1.5 rounded-xl font-medium flex items-center gap-1.5 transition-all cursor-pointer whitespace-nowrap ${
              activeTab === 'guide'
                ? 'bg-blue-600 text-white shadow-sm shadow-blue-500/30'
                : 'text-slate-400 hover:text-white'
            }`}
          >
            <ShieldCheck className="w-3.5 h-3.5" />
            <span>COPPA Policy</span>
          </button>

          <button
            onClick={() => onTabChange('logs')}
            className={`px-3.5 py-1.5 rounded-xl font-medium flex items-center gap-1.5 transition-all cursor-pointer whitespace-nowrap ${
              activeTab === 'logs'
                ? 'bg-blue-600 text-white shadow-sm shadow-blue-500/30'
                : 'text-slate-400 hover:text-white'
            }`}
          >
            <Activity className="w-3.5 h-3.5" />
            <span>AdMob Console</span>
            <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-ping" />
          </button>
        </div>

        {/* Viewport & Live State Badges */}
        <div className="flex items-center gap-3">
          {/* Active Drawing Sentinel Pill */}
          <div
            className={`px-3 py-1 rounded-full text-xs font-semibold flex items-center gap-2 border transition-all ${
              isDrawingActive
                ? 'bg-rose-500/20 text-rose-300 border-rose-500/40 animate-pulse'
                : 'bg-emerald-500/10 text-emerald-300 border-emerald-500/30'
            }`}
          >
            <span className={`w-2 h-2 rounded-full ${isDrawingActive ? 'bg-rose-400' : 'bg-emerald-400'}`} />
            <span>{isDrawingActive ? 'Drawing Active (Ads Suppressed)' : 'Canvas Idle (Ads Permitted)'}</span>
          </div>

          {/* Viewport Toggle (when in simulator mode) */}
          {activeTab === 'simulator' && (
            <div className="flex items-center bg-slate-900/80 p-1 rounded-xl border border-white/10 text-xs">
              <button
                onClick={() => setDeviceViewport('mobile')}
                className={`p-1.5 rounded-lg transition-colors cursor-pointer ${
                  deviceViewport === 'mobile' ? 'bg-blue-600 text-white' : 'text-slate-400 hover:text-white'
                }`}
                title="Mobile Portrait View (390px)"
              >
                <Smartphone className="w-3.5 h-3.5" />
              </button>
              <button
                onClick={() => setDeviceViewport('tablet')}
                className={`p-1.5 rounded-lg transition-colors cursor-pointer ${
                  deviceViewport === 'tablet' ? 'bg-blue-600 text-white' : 'text-slate-400 hover:text-white'
                }`}
                title="Tablet Landscape / Expanded View"
              >
                <Monitor className="w-3.5 h-3.5" />
              </button>
            </div>
          )}
        </div>
      </div>

      {/* 2. Main Stage Canvas */}
      <div className="flex-1 overflow-y-auto p-4 sm:p-6 lg:p-8 flex items-center justify-center bg-radial from-[#0D1527] to-[#0A0F1D]">
        {/* Tab 1: Interactive Kids Drawing Studio in Mobile/Tablet Frame */}
        {activeTab === 'simulator' && (
          <div
            className={`transition-all duration-300 w-full ${
              deviceViewport === 'mobile'
                ? 'max-w-[440px]'
                : 'max-w-4xl'
            }`}
          >
            <div className="relative rounded-[36px] p-2 bg-gradient-to-b from-slate-700 via-slate-800 to-slate-900 shadow-2xl shadow-black/80 border border-white/15">
              <div className="absolute top-4 left-1/2 -translate-x-1/2 w-28 h-4 bg-slate-950 rounded-full z-30 flex items-center justify-center">
                <div className="w-2.5 h-2.5 rounded-full bg-slate-800 mr-2" />
                <div className="w-1.5 h-1.5 rounded-full bg-blue-900" />
              </div>

              <div className="rounded-[28px] overflow-hidden bg-white text-slate-900 border border-black/40">
                <KidsDrawingStudio
                  config={config}
                  onRequestUnlock={onRequestUnlock}
                  unlockedPages={unlockedPages}
                  onShowInterstitialDirectly={onShowInterstitialDirectly}
                />
              </div>
            </div>
          </div>
        )}

        {/* Tab 2: Flutter Source Code Viewer */}
        {activeTab === 'code' && (
          <div className="w-full max-w-5xl h-full">
            <FlutterCodeViewer
              config={config}
              onUpdateConfig={onUpdateConfig}
              isUsingTestIds={isUsingTestIds}
              onToggleTestIds={onToggleTestIds}
            />
          </div>
        )}

        {/* Tab 3: Interactive Unit & Widget Test Suite */}
        {activeTab === 'tests' && (
          <div className="w-full max-w-4xl bg-slate-950 border border-white/10 rounded-3xl p-6 shadow-2xl space-y-6">
            <div className="flex flex-wrap items-center justify-between gap-3 pb-4 border-b border-white/10">
              <div>
                <div className="flex items-center gap-2">
                  <FileCheck className="w-5 h-5 text-emerald-400" />
                  <h3 className="text-base font-bold text-white">Flutter Test Scenarios (Demo Only)</h3>
                </div>
                <p className="text-xs text-slate-400 mt-1">
                  Mock examples only — this browser dashboard does not execute Flutter tests or static analysis.
                </p>
              </div>

              <div className="flex items-center gap-3">
                <span className="text-[11px] text-slate-400 font-mono">Last demo replay: {testRunTimestamp}</span>
                <button
                  onClick={handleRerunTests}
                  disabled={isRunningTests}
                  className="px-3.5 py-1.5 bg-emerald-600 hover:bg-emerald-500 disabled:opacity-50 text-white text-xs font-bold rounded-xl shadow-xs flex items-center gap-1.5 transition-all cursor-pointer active:scale-95"
                >
                  <RotateCw className={`w-3.5 h-3.5 ${isRunningTests ? 'animate-spin' : ''}`} />
                  <span>{isRunningTests ? 'Replaying Demo...' : 'Replay Demo Checks'}</span>
                </button>
              </div>
            </div>

            {/* Static Analysis Badge */}
            <div className="p-3 bg-slate-900/90 border border-emerald-500/30 rounded-2xl flex items-center justify-between text-xs font-mono">
              <div className="flex items-center gap-2 text-emerald-400">
                <CheckCircle2 className="w-4 h-4 shrink-0" />
                <span>$ flutter analyze --no-pub</span>
              </div>
              <span className="text-slate-300">Not executed here — use GitHub Actions to run real Flutter analysis.</span>
            </div>

            {/* Test Groups */}
            <div className="space-y-4 max-h-[460px] overflow-y-auto pr-1">
              {unitTestCases.map((group, gIdx) => (
                <div key={gIdx} className="p-4 bg-slate-900/60 border border-white/5 rounded-2xl space-y-2.5">
                  <div className="flex items-center justify-between text-xs font-semibold text-slate-300">
                    <span>{group.group}</span>
                    <span className="text-[11px] font-mono text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded border border-emerald-500/20">
                      DEMO
                    </span>
                  </div>

                  <div className="space-y-1.5">
                    {group.tests.map((test) => (
                      <div
                        key={test.id}
                        className="p-2.5 bg-slate-950/70 border border-white/5 rounded-xl flex items-center justify-between text-xs font-mono"
                      >
                        <div className="flex items-center gap-2 text-slate-200">
                          <CheckCircle2 className="w-3.5 h-3.5 text-emerald-400 shrink-0" />
                          <span className="text-[11px]">{test.name}</span>
                        </div>
                        <div className="flex items-center gap-3 text-[10px] text-slate-500">
                          <span className="hidden sm:inline text-slate-400">{test.detail}</span>
                          <span className="text-emerald-400 font-semibold">{test.duration}</span>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Tab 4: COPPA & Families Policy Guide */}
        {activeTab === 'guide' && (
          <div className="w-full max-w-5xl">
            <PolicyBadgeGuide />
          </div>
        )}

        {/* Tab 5: AdMob SDK Telemetry & Event Logger */}
        {activeTab === 'logs' && (
          <div className="w-full max-w-4xl bg-slate-950 border border-white/10 rounded-3xl p-6 shadow-2xl">
            <div className="flex items-center justify-between pb-4 mb-4 border-b border-white/10">
              <div className="flex items-center gap-2">
                <Terminal className="w-5 h-5 text-emerald-400" />
                <h3 className="text-base font-bold text-white">AdMob Real-Time Console & Policy Diagnostics</h3>
              </div>
              <span className="text-xs font-mono text-emerald-400 bg-emerald-500/10 px-2 py-0.5 rounded border border-emerald-500/20">
                LISTENER: ACTIVE
              </span>
            </div>

            <div className="space-y-2.5 font-mono text-xs max-h-[500px] overflow-y-auto pr-2">
              {adLogs.map((log) => (
                <div
                  key={log.id}
                  className={`p-3 rounded-xl border flex items-start gap-3 ${
                    log.type === 'warn'
                      ? 'bg-rose-500/10 border-rose-500/30 text-rose-300'
                      : log.type === 'success'
                      ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-300'
                      : 'bg-slate-900/80 border-white/5 text-slate-300'
                  }`}
                >
                  <span className="text-slate-500 shrink-0 text-[11px]">{log.time}</span>
                  <div className="flex-1 leading-relaxed">
                    {log.type === 'warn' && <AlertTriangle className="w-3.5 h-3.5 inline mr-1 text-rose-400" />}
                    {log.type === 'success' && <CheckCircle2 className="w-3.5 h-3.5 inline mr-1 text-emerald-400" />}
                    <span>{log.text}</span>
                  </div>
                </div>
              ))}
            </div>

            {/* Invariants Checklist Bar */}
            <div className="mt-6 pt-4 border-t border-white/10 grid grid-cols-2 sm:grid-cols-4 gap-3 text-xs">
              <div className="p-3 bg-slate-900 rounded-xl border border-white/5">
                <span className="text-slate-400 block text-[10px]">COPPA Flag:</span>
                <span className="text-emerald-400 font-semibold font-mono">ChildDirected = 1</span>
              </div>
              <div className="p-3 bg-slate-900 rounded-xl border border-white/5">
                <span className="text-slate-400 block text-[10px]">Content Ceiling:</span>
                <span className="text-emerald-400 font-semibold font-mono">Rating = 'G'</span>
              </div>
              <div className="p-3 bg-slate-900 rounded-xl border border-white/5">
                <span className="text-slate-400 block text-[10px]">NPA Flag:</span>
                <span className="text-cyan-400 font-semibold font-mono">extras: npa='1'</span>
              </div>
              <div className="p-3 bg-slate-900 rounded-xl border border-white/5">
                <span className="text-slate-400 block text-[10px]">Drawing Sentinel:</span>
                <span className={`font-semibold font-mono ${isDrawingActive ? 'text-rose-400' : 'text-emerald-400'}`}>
                  {isDrawingActive ? 'SUPPRESSING' : 'READY'}
                </span>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
