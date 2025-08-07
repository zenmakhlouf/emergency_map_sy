import React, { useState } from 'react';
import { Button } from './ui/button';
import { Card, CardContent, CardHeader, CardTitle } from './ui/card';
import { Badge } from './ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from './ui/tabs';
import { 
  AlertTriangle, 
  MapPin, 
  MessageSquare, 
  Plus, 
  User, 
  Phone,
  Flame,
  Car,
  Heart,
  Shield
} from 'lucide-react';
import { StaticMap, sampleMarkers } from './StaticMap';

export function CitizenDashboard() {
  const [activeTab, setActiveTab] = useState('map');

  const incidents = [
    { 
      id: 1, 
      type: 'fire', 
      title: 'Building Fire', 
      location: '123 Main St', 
      severity: 'high',
      distance: '0.5 miles',
      time: '5 min ago',
      status: 'active'
    },
    { 
      id: 2, 
      type: 'medical', 
      title: 'Medical Emergency', 
      location: '456 Oak Ave', 
      severity: 'medium',
      distance: '1.2 miles',
      time: '12 min ago',
      status: 'responding'
    },
    { 
      id: 3, 
      type: 'accident', 
      title: 'Vehicle Accident', 
      location: '789 Elm St', 
      severity: 'low',
      distance: '2.1 miles',
      time: '25 min ago',
      status: 'resolved'
    },
  ];

  const getIncidentIcon = (type: string) => {
    switch (type) {
      case 'fire': return <Flame className="w-5 h-5" />;
      case 'medical': return <Heart className="w-5 h-5" />;
      case 'accident': return <Car className="w-5 h-5" />;
      default: return <AlertTriangle className="w-5 h-5" />;
    }
  };

  const getSeverityColor = (severity: string) => {
    switch (severity) {
      case 'high': return 'bg-red-500';
      case 'medium': return 'bg-yellow-500';
      case 'low': return 'bg-green-500';
      default: return 'bg-gray-500';
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'active': return 'destructive';
      case 'responding': return 'default';
      case 'resolved': return 'secondary';
      default: return 'outline';
    }
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <div className="bg-white shadow-sm p-4">
        <div className="flex justify-between items-center">
          <div>
            <h1 className="text-xl font-semibold text-gray-900">SafetyConnect</h1>
            <p className="text-sm text-gray-600">Stay informed and safe</p>
          </div>
          <Button size="sm" variant="outline">
            <User className="w-4 h-4" />
          </Button>
        </div>
      </div>

      <Tabs value={activeTab} onValueChange={setActiveTab} className="flex-1">
        <TabsContent value="map" className="m-0">
          <div className="p-4 space-y-4">
            {/* Live Incident Map */}
            <Card>
              <CardHeader>
                <CardTitle className="text-lg flex items-center gap-2">
                  <MapPin className="w-5 h-5" />
                  Live Incident Map
                </CardTitle>
              </CardHeader>
              <CardContent className="p-0">
                <StaticMap 
                  markers={sampleMarkers}
                  className="h-64"
                />
              </CardContent>
            </Card>

            {/* Emergency Report Button */}
            <Button 
              size="lg" 
              className="w-full bg-red-600 hover:bg-red-700 text-white"
            >
              <Plus className="w-5 h-5 mr-2" />
              Report Emergency
            </Button>

            {/* Recent Incidents */}
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">Nearby Incidents</CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                {incidents.map((incident) => (
                  <div key={incident.id} className="flex items-start space-x-3 p-3 rounded-lg bg-gray-50">
                    <div className={`w-8 h-8 rounded-full flex items-center justify-center ${getSeverityColor(incident.severity)} text-white`}>
                      {getIncidentIcon(incident.type)}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center justify-between mb-1">
                        <h4 className="font-medium text-gray-900 truncate">{incident.title}</h4>
                        <Badge variant={getStatusColor(incident.status) as any} className="text-xs">
                          {incident.status}
                        </Badge>
                      </div>
                      <p className="text-sm text-gray-600">{incident.location}</p>
                      <div className="flex justify-between items-center mt-1">
                        <span className="text-xs text-gray-500">{incident.distance} away</span>
                        <span className="text-xs text-gray-500">{incident.time}</span>
                      </div>
                    </div>
                  </div>
                ))}
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        <TabsContent value="reports" className="m-0">
          <div className="p-4">
            <Card>
              <CardHeader>
                <CardTitle>My Reports</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-center py-8">
                  <AlertTriangle className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                  <p className="text-gray-500">No reports submitted yet</p>
                  <Button className="mt-4 bg-red-600 hover:bg-red-700">
                    <Plus className="w-4 h-4 mr-2" />
                    Report Emergency
                  </Button>
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        <TabsContent value="chat" className="m-0">
          <div className="p-4">
            <Card>
              <CardHeader>
                <CardTitle>Emergency Chat</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="text-center py-8">
                  <MessageSquare className="w-12 h-12 text-gray-400 mx-auto mb-4" />
                  <p className="text-gray-500">No active conversations</p>
                  <p className="text-sm text-gray-400 mt-2">Chat will appear here when you report an emergency</p>
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* Bottom Navigation */}
        <div className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200">
          <TabsList className="grid w-full grid-cols-3 h-16 bg-transparent">
            <TabsTrigger 
              value="map" 
              className="flex-col gap-1 data-[state=active]:bg-red-50 data-[state=active]:text-red-600"
            >
              <MapPin className="w-5 h-5" />
              <span className="text-xs">Map</span>
            </TabsTrigger>
            <TabsTrigger 
              value="reports" 
              className="flex-col gap-1 data-[state=active]:bg-red-50 data-[state=active]:text-red-600"
            >
              <AlertTriangle className="w-5 h-5" />
              <span className="text-xs">Reports</span>
            </TabsTrigger>
            <TabsTrigger 
              value="chat" 
              className="flex-col gap-1 data-[state=active]:bg-red-50 data-[state=active]:text-red-600"
            >
              <MessageSquare className="w-5 h-5" />
              <span className="text-xs">Chat</span>
            </TabsTrigger>
          </TabsList>
        </div>
      </Tabs>
    </div>
  );
}