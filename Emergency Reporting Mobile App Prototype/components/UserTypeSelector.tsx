import React from 'react';
import { Button } from './ui/button';
import { Card } from './ui/card';
import { Shield, Users, Settings } from 'lucide-react';

interface UserTypeSelectorProps {
  onSelectUserType: (type: 'citizen' | 'responder' | 'coordinator') => void;
}

export function UserTypeSelector({ onSelectUserType }: UserTypeSelectorProps) {
  return (
    <div className="min-h-screen bg-gradient-to-b from-red-50 to-red-100 flex items-center justify-center p-4">
      <div className="w-full max-w-sm space-y-6">
        <div className="text-center space-y-2">
          <div className="w-20 h-20 bg-red-600 rounded-full flex items-center justify-center mx-auto mb-4">
            <Shield className="w-10 h-10 text-white" />
          </div>
          <h1 className="text-2xl font-bold text-red-900">SafetyConnect</h1>
          <p className="text-red-700">Emergency Reporting & Safety System</p>
        </div>
        
        <div className="space-y-4">
          <Card className="p-6 hover:shadow-lg transition-shadow cursor-pointer" 
                onClick={() => onSelectUserType('citizen')}>
            <div className="flex items-center space-x-4">
              <div className="w-12 h-12 bg-blue-100 rounded-full flex items-center justify-center">
                <Users className="w-6 h-6 text-blue-600" />
              </div>
              <div className="flex-1">
                <h3 className="font-semibold text-gray-900">I'm a Citizen</h3>
                <p className="text-sm text-gray-600">Report emergencies and view incidents</p>
              </div>
            </div>
          </Card>
          
          <Card className="p-6 hover:shadow-lg transition-shadow cursor-pointer"
                onClick={() => onSelectUserType('responder')}>
            <div className="flex items-center space-x-4">
              <div className="w-12 h-12 bg-red-100 rounded-full flex items-center justify-center">
                <Shield className="w-6 h-6 text-red-600" />
              </div>
              <div className="flex-1">
                <h3 className="font-semibold text-gray-900">I'm a Responder</h3>
                <p className="text-sm text-gray-600">Police, Fire, Medical, or Volunteer</p>
              </div>
            </div>
          </Card>

          <Card className="p-6 hover:shadow-lg transition-shadow cursor-pointer"
                onClick={() => onSelectUserType('coordinator')}>
            <div className="flex items-center space-x-4">
              <div className="w-12 h-12 bg-green-100 rounded-full flex items-center justify-center">
                <Settings className="w-6 h-6 text-green-600" />
              </div>
              <div className="flex-1">
                <h3 className="font-semibold text-gray-900">I'm a Coordinator</h3>
                <p className="text-sm text-gray-600">Emergency Operations Center Staff</p>
              </div>
            </div>
          </Card>
        </div>
      </div>
    </div>
  );
}