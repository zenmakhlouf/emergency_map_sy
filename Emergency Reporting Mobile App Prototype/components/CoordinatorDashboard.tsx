import React, { useState } from 'react';
import { Button } from './ui/button';
import { Card, CardContent, CardHeader, CardTitle } from './ui/card';
import { Badge } from './ui/badge';
import { Tabs, TabsContent, TabsList, TabsTrigger } from './ui/tabs';
import { Input } from './ui/input';
import { Textarea } from './ui/textarea';
import { StaticMap, sampleMarkers } from './StaticMap';
import { 
  Settings, 
  MapPin, 
  MessageSquare, 
  User,
  AlertTriangle,
  Shield,
  Users,
  Phone,
  Navigation,
  Clock,
  CheckCircle,
  XCircle,
  Edit,
  Trash2,
  Bell,
  Filter,
  Search,
  MoreVertical,
  UserCheck,
  Target
} from 'lucide-react';

export function CoordinatorDashboard() {
  const [activeTab, setActiveTab] = useState('incidents');
  const [selectedIncident, setSelectedIncident] = useState<string | null>(null);

  const incidents = [
    {
      id: '1',
      title: 'Apartment Building Fire',
      category: 'fire',
      severity: 'high',
      location: '123 Main St, Apt 4B',
      reporter: 'John D. (+1-555-0123)',
      time: '3 min ago',
      status: 'active',
      assignedResponders: ['Unit F-1', 'Unit F-2'],
      description: 'Smoke visible from 3rd floor. Multiple residents evacuating.',
      coordinates: { lat: 40.7130, lng: -74.0055 }
    },
    {
      id: '2',
      title: 'Medical Emergency - Cardiac',
      category: 'medical',
      severity: 'critical',
      location: '789 Oak Avenue',
      reporter: 'Sarah M. (+1-555-0456)',
      time: '8 min ago',
      status: 'responding',
      assignedResponders: ['AMB-1'],
      description: 'Elderly male, chest pain, difficulty breathing.',
      coordinates: { lat: 40.7135, lng: -74.0045 }
    },
    {
      id: '3',
      title: 'Traffic Accident',
      category: 'traffic',
      severity: 'medium',
      location: '456 Pine Street Intersection',
      reporter: 'Anonymous',
      time: '15 min ago',
      status: 'resolved',
      assignedResponders: ['PD-3'],
      description: 'Minor fender bender, no injuries reported.',
      coordinates: { lat: 40.7120, lng: -74.0070 }
    }
  ];

  const responders = [
    {
      id: 'f1',
      name: 'Fire Unit F-1',
      type: 'fire',
      status: 'responding',
      location: '2 blocks from incident',
      eta: '2 min',
      contact: 'Ch. 16',
      incidents: ['1']
    },
    {
      id: 'amb1',
      name: 'Ambulance AMB-1',
      type: 'medical',
      status: 'on-scene',
      location: '789 Oak Avenue',
      eta: 'Arrived',
      contact: 'Ch. 8',
      incidents: ['2']
    },
    {
      id: 'pd3',
      name: 'Police PD-3',
      type: 'police',
      status: 'available',
      location: 'Downtown Patrol',
      eta: 'N/A',
      contact: 'Ch. 12',
      incidents: []
    }
  ];

  const getSeverityColor = (severity: string) => {
    switch (severity) {
      case 'critical': return 'bg-red-600';
      case 'high': return 'bg-orange-500';
      case 'medium': return 'bg-yellow-500';
      case 'low': return 'bg-green-500';
      default: return 'bg-gray-500';
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'active': return 'bg-red-100 text-red-800';
      case 'responding': return 'bg-blue-100 text-blue-800';
      case 'resolved': return 'bg-green-100 text-green-800';
      default: return 'bg-gray-100 text-gray-800';
    }
  };

  return (
    <div className="min-h-screen bg-gray-50">
      {/* Header */}
      <div className="bg-green-600 text-white p-4 shadow-lg">
        <div className="flex justify-between items-center">
          <div>
            <h1 className="text-lg font-semibold">Emergency Operations Center</h1>
            <p className="text-sm text-green-100">Coordinator Dashboard - District 5</p>
          </div>
          <div className="text-right">
            <div className="flex items-center gap-2 mb-1">
              <div className="w-2 h-2 bg-green-400 rounded-full" />
              <span className="text-sm">Online</span>
            </div>
            <Button size="sm" variant="secondary">
              <User className="w-4 h-4" />
            </Button>
          </div>
        </div>
      </div>

      {/* Stats Overview */}
      <div className="p-4 grid grid-cols-4 gap-3">
        <Card className="text-center">
          <CardContent className="p-3">
            <div className="text-lg font-bold text-red-600">3</div>
            <div className="text-xs text-gray-600">Active</div>
          </CardContent>
        </Card>
        <Card className="text-center">
          <CardContent className="p-3">
            <div className="text-lg font-bold text-blue-600">5</div>
            <div className="text-xs text-gray-600">Responding</div>
          </CardContent>
        </Card>
        <Card className="text-center">
          <CardContent className="p-3">
            <div className="text-lg font-bold text-green-600">12</div>
            <div className="text-xs text-gray-600">Available</div>
          </CardContent>
        </Card>
        <Card className="text-center">
          <CardContent className="p-3">
            <div className="text-lg font-bold text-gray-600">24</div>
            <div className="text-xs text-gray-600">Today</div>
          </CardContent>
        </Card>
      </div>

      <Tabs value={activeTab} onValueChange={setActiveTab} className="flex-1">
        <TabsContent value="incidents" className="m-0">
          <div className="p-4 space-y-4">
            {/* Search and Filter */}
            <div className="flex gap-2">
              <div className="flex-1 relative">
                <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
                <Input placeholder="Search incidents..." className="pl-10" />
              </div>
              <Button variant="outline" size="sm">
                <Filter className="w-4 h-4" />
              </Button>
            </div>

            {/* Incidents List */}
            <div className="space-y-3">
              {incidents.map((incident) => (
                <Card 
                  key={incident.id} 
                  className={`border-l-4 ${
                    incident.severity === 'critical' ? 'border-l-red-600' :
                    incident.severity === 'high' ? 'border-l-orange-500' :
                    'border-l-yellow-500'
                  } ${selectedIncident === incident.id ? 'ring-2 ring-green-500' : ''}`}
                  onClick={() => setSelectedIncident(selectedIncident === incident.id ? null : incident.id)}
                >
                  <CardContent className="p-4">
                    <div className="flex items-start justify-between mb-3">
                      <div className="flex items-center gap-2">
                        <div className={`w-8 h-8 rounded-full flex items-center justify-center ${getSeverityColor(incident.severity)} text-white`}>
                          <AlertTriangle className="w-4 h-4" />
                        </div>
                        <div>
                          <h3 className="font-semibold text-gray-900">{incident.title}</h3>
                          <p className="text-sm text-gray-600">{incident.location}</p>
                        </div>
                      </div>
                      <div className="flex items-center gap-2">
                        <Badge className={`text-xs ${getStatusColor(incident.status)}`}>
                          {incident.status.toUpperCase()}
                        </Badge>
                        <Button variant="ghost" size="sm">
                          <MoreVertical className="w-4 h-4" />
                        </Button>
                      </div>
                    </div>

                    <div className="space-y-2 mb-3">
                      <div className="flex items-center gap-2 text-sm text-gray-600">
                        <User className="w-4 h-4" />
                        <span>{incident.reporter}</span>
                      </div>
                      <div className="flex items-center gap-2 text-sm text-gray-600">
                        <Clock className="w-4 h-4" />
                        <span>{incident.time}</span>
                      </div>
                    </div>

                    {selectedIncident === incident.id && (
                      <div className="border-t pt-3 space-y-3">
                        <p className="text-sm text-gray-700">{incident.description}</p>
                        
                        <div className="flex flex-wrap gap-2">
                          {incident.assignedResponders.map((responder) => (
                            <Badge key={responder} variant="outline" className="text-xs">
                              {responder}
                            </Badge>
                          ))}
                        </div>

                        <div className="grid grid-cols-2 gap-2">
                          <Button size="sm" variant="outline" className="text-xs">
                            <Phone className="w-3 h-3 mr-1" />
                            Call Reporter
                          </Button>
                          <Button size="sm" variant="outline" className="text-xs">
                            <MessageSquare className="w-3 h-3 mr-1" />
                            Chat
                          </Button>
                          <Button size="sm" variant="outline" className="text-xs">
                            <Edit className="w-3 h-3 mr-1" />
                            Update Info
                          </Button>
                          <Button size="sm" variant="outline" className="text-xs">
                            <Bell className="w-3 h-3 mr-1" />
                            Notify
                          </Button>
                        </div>

                        <div className="flex gap-2">
                          <Button size="sm" className="flex-1 bg-green-600 hover:bg-green-700 text-xs">
                            <UserCheck className="w-3 h-3 mr-1" />
                            Assign Responder
                          </Button>
                          <Button size="sm" variant="destructive" className="text-xs">
                            <Trash2 className="w-3 h-3" />
                          </Button>
                        </div>
                      </div>
                    )}
                  </CardContent>
                </Card>
              ))}
            </div>
          </div>
        </TabsContent>

        <TabsContent value="map" className="m-0">
          <div className="p-4 space-y-4">
            <Card>
              <CardHeader>
                <CardTitle className="text-lg flex items-center gap-2">
                  <MapPin className="w-5 h-5" />
                  Live Operations Map
                </CardTitle>
              </CardHeader>
              <CardContent className="p-0">
                <StaticMap 
                  markers={sampleMarkers}
                  className="h-96"
                />
              </CardContent>
            </Card>

            {/* Map Controls */}
            <div className="grid grid-cols-3 gap-2">
              <Button variant="outline" size="sm" className="text-xs">
                <Target className="w-3 h-3 mr-1" />
                Track All
              </Button>
              <Button variant="outline" size="sm" className="text-xs">
                <Users className="w-3 h-3 mr-1" />
                Citizens
              </Button>
              <Button variant="outline" size="sm" className="text-xs">
                <Shield className="w-3 h-3 mr-1" />
                Responders
              </Button>
            </div>
          </div>
        </TabsContent>

        <TabsContent value="responders" className="m-0">
          <div className="p-4 space-y-4">
            <div className="space-y-3">
              {responders.map((responder) => (
                <Card key={responder.id}>
                  <CardContent className="p-4">
                    <div className="flex items-start justify-between mb-3">
                      <div className="flex items-center gap-2">
                        <div className="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center">
                          <Shield className="w-4 h-4 text-blue-600" />
                        </div>
                        <div>
                          <h3 className="font-semibold text-gray-900">{responder.name}</h3>
                          <p className="text-sm text-gray-600">{responder.location}</p>
                        </div>
                      </div>
                      <Badge className={`text-xs ${
                        responder.status === 'available' ? 'bg-green-100 text-green-800' :
                        responder.status === 'responding' ? 'bg-blue-100 text-blue-800' :
                        'bg-orange-100 text-orange-800'
                      }`}>
                        {responder.status.toUpperCase()}
                      </Badge>
                    </div>

                    <div className="space-y-2 mb-3">
                      <div className="flex items-center justify-between text-sm">
                        <span className="text-gray-600">ETA: {responder.eta}</span>
                        <span className="text-gray-600">Contact: {responder.contact}</span>
                      </div>
                    </div>

                    <div className="flex gap-2">
                      <Button size="sm" variant="outline" className="flex-1 text-xs">
                        <Navigation className="w-3 h-3 mr-1" />
                        Track Location
                      </Button>
                      <Button size="sm" variant="outline" className="flex-1 text-xs">
                        <MessageSquare className="w-3 h-3 mr-1" />
                        Radio
                      </Button>
                      <Button size="sm" className="flex-1 bg-green-600 hover:bg-green-700 text-xs">
                        <Target className="w-3 h-3 mr-1" />
                        Assign
                      </Button>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          </div>
        </TabsContent>

        <TabsContent value="chat" className="m-0">
          <div className="p-4 space-y-4">
            <Card>
              <CardHeader>
                <CardTitle className="text-lg">Active Communications</CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <div className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-red-500 rounded-full flex items-center justify-center text-white">
                      <AlertTriangle className="w-5 h-5" />
                    </div>
                    <div>
                      <p className="font-medium">Building Fire - John D.</p>
                      <p className="text-sm text-gray-600">Last: "Fire department arrived"</p>
                    </div>
                  </div>
                  <div className="text-right">
                    <Badge className="mb-1">3 new</Badge>
                    <p className="text-xs text-gray-500">2 min ago</p>
                  </div>
                </div>

                <div className="flex items-center justify-between p-3 bg-gray-50 rounded-lg">
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 bg-blue-500 rounded-full flex items-center justify-center text-white">
                      <Shield className="w-5 h-5" />
                    </div>
                    <div>
                      <p className="font-medium">Fire Unit F-1</p>
                      <p className="text-sm text-gray-600">Last: "On scene, beginning suppression"</p>
                    </div>
                  </div>
                  <p className="text-xs text-gray-500">1 min ago</p>
                </div>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* Bottom Navigation */}
        <div className="fixed bottom-0 left-0 right-0 bg-white border-t border-gray-200">
          <TabsList className="grid w-full grid-cols-4 h-16 bg-transparent">
            <TabsTrigger 
              value="incidents" 
              className="flex-col gap-1 data-[state=active]:bg-green-50 data-[state=active]:text-green-600"
            >
              <AlertTriangle className="w-5 h-5" />
              <span className="text-xs">Incidents</span>
            </TabsTrigger>
            <TabsTrigger 
              value="map" 
              className="flex-col gap-1 data-[state=active]:bg-green-50 data-[state=active]:text-green-600"
            >
              <MapPin className="w-5 h-5" />
              <span className="text-xs">Map</span>
            </TabsTrigger>
            <TabsTrigger 
              value="responders" 
              className="flex-col gap-1 data-[state=active]:bg-green-50 data-[state=active]:text-green-600"
            >
              <Shield className="w-5 h-5" />
              <span className="text-xs">Responders</span>
            </TabsTrigger>
            <TabsTrigger 
              value="chat" 
              className="flex-col gap-1 data-[state=active]:bg-green-50 data-[state=active]:text-green-600"
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