import React, { useState } from 'react';
import { UserTypeSelector } from './components/UserTypeSelector';
import { PhoneAuth } from './components/PhoneAuth';
import { CitizenDashboard } from './components/CitizenDashboard';
import { ResponderDashboard } from './components/ResponderDashboard';
import { CoordinatorDashboard } from './components/CoordinatorDashboard';
import { AIEmergencyChat } from './components/AIEmergencyChat';
import { EmergencyReportForm } from './components/EmergencyReportForm';
import { EmergencyChat } from './components/EmergencyChat';

type Screen = 
  | 'user-select'
  | 'auth'
  | 'citizen-dashboard'
  | 'responder-dashboard'
  | 'coordinator-dashboard'
  | 'ai-emergency-chat'
  | 'emergency-report'
  | 'chat';

type UserType = 'citizen' | 'responder' | 'coordinator' | null;

export default function App() {
  const [currentScreen, setCurrentScreen] = useState<Screen>('user-select');
  const [userType, setUserType] = useState<UserType>(null);
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [emergencyReportData, setEmergencyReportData] = useState<any>(null);

  const handleUserTypeSelect = (type: UserType) => {
    setUserType(type);
    setCurrentScreen('auth');
  };

  const handleAuthenticated = () => {
    setIsAuthenticated(true);
    if (userType === 'citizen') {
      setCurrentScreen('citizen-dashboard');
    } else if (userType === 'responder') {
      setCurrentScreen('responder-dashboard');
    } else {
      setCurrentScreen('coordinator-dashboard');
    }
  };

  const handleBackToUserSelect = () => {
    setCurrentScreen('user-select');
    setUserType(null);
    setIsAuthenticated(false);
  };

  const navigateToAIEmergencyChat = () => {
    setCurrentScreen('ai-emergency-chat');
  };

  const navigateToEmergencyReport = () => {
    setCurrentScreen('emergency-report');
  };

  const navigateToChat = () => {
    setCurrentScreen('chat');
  };

  const navigateBackToDashboard = () => {
    if (userType === 'citizen') {
      setCurrentScreen('citizen-dashboard');
    } else if (userType === 'responder') {
      setCurrentScreen('responder-dashboard');
    } else {
      setCurrentScreen('coordinator-dashboard');
    }
  };

  const handleAIReportComplete = (reportData: any) => {
    setEmergencyReportData(reportData);
    setCurrentScreen('chat');
  };

  const handleManualReportSubmit = () => {
    setCurrentScreen('chat');
  };

  // Render current screen
  switch (currentScreen) {
    case 'user-select':
      return <UserTypeSelector onSelectUserType={handleUserTypeSelect} />;
    
    case 'auth':
      return (
        <PhoneAuth 
          userType={userType!}
          onAuthenticated={handleAuthenticated}
          onBack={handleBackToUserSelect}
        />
      );
    
    case 'citizen-dashboard':
      return (
        <div className="relative">
          <CitizenDashboard />
          {/* Floating Emergency Report Button - AI First */}
          <button 
            onClick={navigateToAIEmergencyChat}
            className="fixed bottom-20 right-4 w-16 h-16 bg-red-600 hover:bg-red-700 text-white rounded-full shadow-lg flex items-center justify-center z-50 transition-all hover:scale-105"
          >
            <span className="text-2xl">🚨</span>
          </button>
        </div>
      );
    
    case 'responder-dashboard':
      return (
        <div className="relative">
          <ResponderDashboard />
          {/* Floating Chat Button */}
          <button 
            onClick={navigateToChat}
            className="fixed bottom-20 right-4 w-12 h-12 bg-blue-600 hover:bg-blue-700 text-white rounded-full shadow-lg flex items-center justify-center z-50 transition-all hover:scale-105"
          >
            <span className="text-lg">💬</span>
          </button>
        </div>
      );

    case 'coordinator-dashboard':
      return <CoordinatorDashboard />;
    
    case 'ai-emergency-chat':
      return (
        <AIEmergencyChat 
          onBack={navigateBackToDashboard}
          onReportComplete={handleAIReportComplete}
          onSwitchToManual={navigateToEmergencyReport}
        />
      );
    
    case 'emergency-report':
      return (
        <EmergencyReportForm 
          onBack={() => setCurrentScreen('ai-emergency-chat')}
          onSubmit={handleManualReportSubmit}
        />
      );
    
    case 'chat':
      return (
        <EmergencyChat 
          onBack={navigateBackToDashboard}
          incidentTitle={
            emergencyReportData?.classification?.category 
              ? `${emergencyReportData.classification.category.toUpperCase()} Emergency`
              : userType === 'citizen' ? 'Emergency Report' : 'Incident Response'
          }
          userType={userType!}
        />
      );
    
    default:
      return <UserTypeSelector onSelectUserType={handleUserTypeSelect} />;
  }
}