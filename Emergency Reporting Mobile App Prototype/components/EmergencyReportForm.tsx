import React, { useState } from 'react';
import { Button } from './ui/button';
import { Card, CardContent, CardHeader, CardTitle } from './ui/card';
import { Textarea } from './ui/textarea';
import { Badge } from './ui/badge';
import { 
  ArrowLeft, 
  Camera, 
  MapPin, 
  Mic, 
  Send,
  Flame,
  Heart,
  Car,
  Shield,
  AlertTriangle,
  Home
} from 'lucide-react';

interface EmergencyReportFormProps {
  onBack: () => void;
  onSubmit: () => void;
}

export function EmergencyReportForm({ onBack, onSubmit }: EmergencyReportFormProps) {
  const [selectedType, setSelectedType] = useState<string | null>(null);
  const [description, setDescription] = useState('');
  const [isRecording, setIsRecording] = useState(false);

  const emergencyTypes = [
    { id: 'fire', icon: Flame, label: 'Fire Emergency', color: 'bg-red-500' },
    { id: 'medical', icon: Heart, label: 'Medical Emergency', color: 'bg-pink-500' },
    { id: 'accident', icon: Car, label: 'Vehicle Accident', color: 'bg-orange-500' },
    { id: 'crime', icon: Shield, label: 'Crime/Violence', color: 'bg-purple-500' },
    { id: 'hazard', icon: AlertTriangle, label: 'Public Hazard', color: 'bg-yellow-500' },
    { id: 'other', icon: Home, label: 'Other Emergency', color: 'bg-gray-500' },
  ];

  const handleSubmit = () => {
    if (selectedType && description.trim()) {
      onSubmit();
    }
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <div className="bg-white shadow-sm p-4">
        <div className="flex items-center">
          <Button variant="ghost" size="sm" onClick={onBack} className="mr-3">
            <ArrowLeft className="w-4 h-4" />
          </Button>
          <div>
            <h1 className="text-lg font-semibold text-gray-900">Report Emergency</h1>
            <p className="text-sm text-gray-600">Get help fast and accurately</p>
          </div>
        </div>
      </div>

      <div className="p-4 space-y-6 pb-24">
        {/* Emergency Type Selection */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">What type of emergency?</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-2 gap-3">
              {emergencyTypes.map((type) => {
                const IconComponent = type.icon;
                return (
                  <Button
                    key={type.id}
                    variant={selectedType === type.id ? "default" : "outline"}
                    className={`h-20 flex-col gap-2 ${
                      selectedType === type.id 
                        ? `${type.color} text-white hover:opacity-90` 
                        : 'hover:bg-gray-50'
                    }`}
                    onClick={() => setSelectedType(type.id)}
                  >
                    <IconComponent className="w-6 h-6" />
                    <span className="text-xs text-center leading-tight">{type.label}</span>
                  </Button>
                );
              })}
            </div>
          </CardContent>
        </Card>

        {/* Location */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg flex items-center gap-2">
              <MapPin className="w-5 h-5" />
              Location
            </CardTitle>
          </CardHeader>
          <CardContent>
            <div className="flex items-center justify-between p-3 bg-green-50 rounded-lg">
              <div>
                <p className="font-medium text-green-800">Using current location</p>
                <p className="text-sm text-green-600">123 Main Street, Anytown</p>
              </div>
              <Badge variant="secondary" className="bg-green-100 text-green-800">
                Accurate
              </Badge>
            </div>
          </CardContent>
        </Card>

        {/* Description */}
        <Card>
          <CardHeader>
            <CardTitle className="text-lg">Describe the situation</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <Textarea
              placeholder="Describe what's happening. Include any important details..."
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              className="min-h-24"
            />
            
            {/* Voice Recording */}
            <div className="flex gap-2">
              <Button
                variant={isRecording ? "destructive" : "outline"}
                size="sm"
                onClick={() => setIsRecording(!isRecording)}
                className="flex-1"
              >
                <Mic className="w-4 h-4 mr-2" />
                {isRecording ? 'Stop Recording' : 'Voice Message'}
              </Button>
              
              <Button variant="outline" size="sm" className="flex-1">
                <Camera className="w-4 h-4 mr-2" />
                Add Photo
              </Button>
            </div>
            
            {isRecording && (
              <div className="flex items-center justify-center p-4 bg-red-50 rounded-lg">
                <div className="flex items-center gap-3">
                  <div className="w-3 h-3 bg-red-500 rounded-full animate-pulse" />
                  <span className="text-red-700">Recording... 00:15</span>
                </div>
              </div>
            )}
          </CardContent>
        </Card>

        {/* AI Assistant Preview */}
        <Card className="border-blue-200 bg-blue-50">
          <CardContent className="p-4">
            <div className="flex items-start gap-3">
              <div className="w-8 h-8 bg-blue-600 rounded-full flex items-center justify-center">
                <Shield className="w-4 h-4 text-white" />
              </div>
              <div className="flex-1">
                <p className="font-medium text-blue-900">AI Emergency Assistant</p>
                <p className="text-sm text-blue-700 mt-1">
                  I'll help clarify details and connect you with the right responders immediately.
                </p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>

      {/* Submit Button */}
      <div className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200 p-4">
        <Button 
          onClick={handleSubmit}
          disabled={!selectedType || !description.trim()}
          size="lg"
          className="w-full bg-red-600 hover:bg-red-700 text-white"
        >
          <Send className="w-5 h-5 mr-2" />
          Submit Emergency Report
        </Button>
      </div>
    </div>
  );
}