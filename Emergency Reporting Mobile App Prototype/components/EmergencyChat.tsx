import React, { useState } from 'react';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Card, CardContent, CardHeader, CardTitle } from './ui/card';
import { Badge } from './ui/badge';
import { 
  ArrowLeft, 
  Send, 
  Phone, 
  Video,
  Shield,
  User,
  Bot,
  Clock,
  MapPin,
  AlertTriangle
} from 'lucide-react';

interface EmergencyChatProps {
  onBack: () => void;
  incidentTitle: string;
  userType: 'citizen' | 'responder';
}

export function EmergencyChat({ onBack, incidentTitle, userType }: EmergencyChatProps) {
  const [message, setMessage] = useState('');
  
  const messages = [
    {
      id: 1,
      sender: 'ai',
      content: "I've received your fire emergency report. Fire department has been notified and is en route. Are you in a safe location?",
      time: '3:45 PM',
      type: 'system'
    },
    {
      id: 2,
      sender: 'user',
      content: "Yes, I'm outside the building now. The fire seems to be getting bigger.",
      time: '3:46 PM',
      type: 'user'
    },
    {
      id: 3,
      sender: 'responder',
      content: "This is Fire Station 12. We're 2 minutes away. Please stay back from the building and direct us to the exact location.",
      time: '3:47 PM',
      type: 'responder',
      responderName: 'Captain Rodriguez',
      responderUnit: 'Fire Dept #12'
    },
    {
      id: 4,
      sender: 'ai',
      content: "Fire department ETA: 90 seconds. Please ensure all residents have evacuated and stay at least 100 feet from the building.",
      time: '3:48 PM',
      type: 'system'
    },
    {
      id: 5,
      sender: 'user',
      content: "I can see the fire truck approaching. There might still be someone on the 3rd floor.",
      time: '3:49 PM',
      type: 'user'
    }
  ];

  const handleSendMessage = () => {
    if (message.trim()) {
      // Handle message sending
      setMessage('');
    }
  };

  const getSenderIcon = (type: string) => {
    switch (type) {
      case 'ai':
      case 'system':
        return <Bot className="w-4 h-4" />;
      case 'responder':
        return <Shield className="w-4 h-4" />;
      default:
        return <User className="w-4 h-4" />;
    }
  };

  const getSenderColor = (type: string) => {
    switch (type) {
      case 'ai':
      case 'system':
        return 'bg-blue-500';
      case 'responder':
        return 'bg-red-500';
      default:
        return 'bg-gray-500';
    }
  };

  return (
    <div className="min-h-screen bg-gray-50 flex flex-col">
      {/* Header */}
      <div className="bg-white shadow-sm p-4">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <Button variant="ghost" size="sm" onClick={onBack}>
              <ArrowLeft className="w-4 h-4" />
            </Button>
            <div>
              <h1 className="font-semibold text-gray-900">{incidentTitle}</h1>
              <div className="flex items-center gap-2 text-sm text-gray-600">
                <div className="w-2 h-2 bg-green-400 rounded-full" />
                <span>Active Response</span>
              </div>
            </div>
          </div>
          <div className="flex gap-2">
            <Button size="sm" variant="outline">
              <Phone className="w-4 h-4" />
            </Button>
            <Button size="sm" variant="outline">
              <Video className="w-4 h-4" />
            </Button>
          </div>
        </div>
      </div>

      {/* Emergency Status Banner */}
      <div className="bg-red-50 border-b border-red-200 p-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <AlertTriangle className="w-4 h-4 text-red-600" />
            <span className="text-sm font-medium text-red-800">High Priority Emergency</span>
          </div>
          <Badge variant="destructive" className="text-xs">ACTIVE</Badge>
        </div>
        <div className="flex items-center gap-4 mt-2 text-xs text-red-700">
          <div className="flex items-center gap-1">
            <Clock className="w-3 h-3" />
            <span>Response time: 2 min</span>
          </div>
          <div className="flex items-center gap-1">
            <MapPin className="w-3 h-3" />
            <span>123 Main St</span>
          </div>
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 p-4 space-y-4 overflow-y-auto">
        {messages.map((msg) => (
          <div key={msg.id} className={`flex ${msg.sender === 'user' ? 'justify-end' : 'justify-start'}`}>
            <div className={`max-w-xs lg:max-w-md ${msg.sender === 'user' ? 'order-2' : 'order-1'}`}>
              {msg.sender !== 'user' && (
                <div className="flex items-center gap-2 mb-1">
                  <div className={`w-6 h-6 rounded-full flex items-center justify-center ${getSenderColor(msg.type)} text-white`}>
                    {getSenderIcon(msg.type)}
                  </div>
                  <span className="text-xs font-medium text-gray-700">
                    {msg.type === 'system' || msg.type === 'ai' 
                      ? 'AI Emergency Assistant' 
                      : msg.responderName || 'Responder'
                    }
                  </span>
                  {msg.responderUnit && (
                    <Badge variant="secondary" className="text-xs">
                      {msg.responderUnit}
                    </Badge>
                  )}
                </div>
              )}
              
              <div className={`px-4 py-2 rounded-2xl ${
                msg.sender === 'user' 
                  ? 'bg-red-600 text-white' 
                  : msg.type === 'system' || msg.type === 'ai'
                    ? 'bg-blue-100 text-blue-900'
                    : 'bg-white border border-gray-200'
              }`}>
                <p className="text-sm">{msg.content}</p>
              </div>
              
              <div className={`text-xs text-gray-500 mt-1 ${msg.sender === 'user' ? 'text-right' : 'text-left'}`}>
                {msg.time}
              </div>
            </div>
          </div>
        ))}
      </div>

      {/* Quick Response (for responders) */}
      {userType === 'responder' && (
        <div className="p-4 bg-gray-100">
          <div className="flex gap-2 mb-3 overflow-x-auto">
            <Button size="sm" variant="outline" className="whitespace-nowrap">
              On my way
            </Button>
            <Button size="sm" variant="outline" className="whitespace-nowrap">
              ETA 5 min
            </Button>
            <Button size="sm" variant="outline" className="whitespace-nowrap">
              Need backup
            </Button>
            <Button size="sm" variant="outline" className="whitespace-nowrap">
              Situation resolved
            </Button>
          </div>
        </div>
      )}

      {/* Message Input */}
      <div className="bg-white border-t border-gray-200 p-4">
        <div className="flex gap-2">
          <Input
            placeholder="Type your message..."
            value={message}
            onChange={(e) => setMessage(e.target.value)}
            onKeyPress={(e) => e.key === 'Enter' && handleSendMessage()}
            className="flex-1"
          />
          <Button 
            onClick={handleSendMessage}
            disabled={!message.trim()}
            className="bg-red-600 hover:bg-red-700"
          >
            <Send className="w-4 h-4" />
          </Button>
        </div>
        <div className="flex justify-between items-center mt-2 text-xs text-gray-500">
          <span>Emergency chat is monitored 24/7</span>
          <div className="flex items-center gap-1">
            <div className="w-2 h-2 bg-green-400 rounded-full" />
            <span>All parties connected</span>
          </div>
        </div>
      </div>
    </div>
  );
}