import Cocoa

/*
 Concrete implementation of a middleman/facade between AppDelegate (UI) and Player. Accepts all requests originating from AppDelegate, converts/marshals them into lower-level requests suitable for Player, and forwards them to Player. Also, notifies AppDelegate when important events (such as playback completion) have occurred in Player.
 
 See AuralPlayerDelegate, AuralSoundTuningDelegate, and EventSubscriber protocols to learn more about the public functions implemented here.
 */
//class PlayerAndPlaylistDelegate {
//    
//    // The current player playlist
//    private let playlist: Playlist
//    
//    // The actual audio player
//    private let player: PlayerProtocol
//    
//    private let appState: AppState
//    private let preferences: Preferences
//    
//    // Currently playing track
//    private var playingTrack: IndexedTrack?
//    
//    // Serial queue for track prep tasks (to prevent concurrent prepping of the same track which could cause contention and is unnecessary to begin with)
//    private var trackPrepQueue: OperationQueue
//    
//    // See PlaybackState
//    private var playbackState: PlaybackState = .noTrack
//    
//    init(_ playlist: Playlist, _ player: PlayerProtocol, _ appState: AppState, _ preferences: Preferences) {
//        
//        self.playlist = playlist
//        self.player = player
//        
//        self.appState = appState
//        self.preferences = preferences
//        
//        self.trackPrepQueue = OperationQueue()
//        trackPrepQueue.underlyingQueue = DispatchQueue.global(qos: DispatchQoS.QoSClass.background)
//        trackPrepQueue.maxConcurrentOperationCount = 1
//        
//        EventRegistry.subscribe(EventType.playbackCompleted, subscriber: self, dispatchQueue: DispatchQueue.global(qos: DispatchQoS.QoSClass.userInteractive))
//        
//        SyncMessenger.subscribe(.appLoadedNotification, subscriber: self)
//    }
//    
//    // This is called when the app loads initially. Loads the playlist from the app state file on disk. Only meant to be called once.
//    private func loadPlaylistFromSavedState() {
//        
//        // Add tracks async, notifying the UI one at a time
//        DispatchQueue.global(qos: .userInteractive).async {
//            
//            // NOTE - Assume that all entries are valid tracks (supported audio files), not playlists and not directories. i.e. assume that saved state file has not been corrupted.
//            
//            var errors: [InvalidTrackError] = [InvalidTrackError]()
//            let autoplay: Bool = self.preferences.autoplayOnStartup
//            var autoplayed: Bool = false
//            
//            let tracks = self.appState.playlistState.tracks
//            let totalTracks = tracks.count
//            var tracksAdded = 0
//            
//            for trackPath in tracks {
//                
//                tracksAdded += 1
//                
//                // Playlists might contain broken file references
//                if (!FileSystemUtils.fileExists(trackPath)) {
//                    errors.append(FileNotFoundError(URL(fileURLWithPath: trackPath)))
//                    continue
//                }
//                
//                let resolvedFileInfo = FileSystemUtils.resolveTruePath(URL(fileURLWithPath: trackPath))
//                
//                do {
//                    
//                    let progress = TrackAddedEventProgress(tracksAdded, totalTracks)
//                    try self.addTrack(resolvedFileInfo.resolvedURL, progress)
//                    
//                    if (autoplay && !autoplayed) {
//                        self.autoplay()
//                        autoplayed = true
//                    }
//                    
//                } catch let error as Error {
//                    
//                    if (error is InvalidTrackError) {
//                        errors.append(error as! InvalidTrackError)
//                    }
//                }
//            }
//            
//            EventRegistry.publishEvent(.doneAddingTracks, DoneAddingTracksEvent.instance)
//            
//            // If errors > 0, send event to UI
//            if (errors.count > 0) {
//                EventRegistry.publishEvent(.tracksNotAdded, TracksNotAddedEvent(errors))
//            }
//        }
//    }
//    
//    func autoplay() {
//        
//        DispatchQueue.main.async {
//            
//            do {
//                
//                try self.continuePlaying()
//                
//            } catch let error as Error {
//                
//                if (error is InvalidTrackError) {
//                    EventRegistry.publishEvent(.trackNotPlayed, TrackNotPlayedEvent(error as! InvalidTrackError))
//                }
//            }
//            
//            // Notify the UI that a track has started playing
//            EventRegistry.publishEvent(.trackChanged, TrackChangedEvent(self.playingTrack))
//        }
//    }
//    
//    func autoplay(_ trackIndex: Int) {
//        
//        DispatchQueue.main.async {
//            
//            do {
//                try self.play(trackIndex)
//                
//            } catch let error as Error {
//                
//                if (error is InvalidTrackError) {
//                    EventRegistry.publishEvent(.trackNotPlayed, TrackNotPlayedEvent(error as! InvalidTrackError))
//                }
//            }
//            
//            // Notify the UI that a track has started playing
//            EventRegistry.publishEvent(.trackChanged, TrackChangedEvent(self.playingTrack))
//        }
//    }
//    
//    func getappState() -> AppState {
//        return appState
//    }
//    
//    // This method should only be called from outside this class. For adding tracks within this class, always call the private method addFiles_sync().
//    func addFiles(_ files: [URL]) {
//        
//        EventRegistry.publishEvent(.startedAddingTracks, StartedAddingTracksEvent.instance)
//        
//        // Move to a background thread to unblock the main thread
//        DispatchQueue.global(qos: .userInteractive).async {
//            
//            let autoplayPref: Bool = self.preferences.autoplayAfterAddingTracks
//            let alwaysAutoplay: Bool = self.preferences.autoplayAfterAddingOption == .always
//            let noPlayingTrack: Bool = self.playingTrack == nil
//            
//            // Autoplay if the preference is selected AND either the "always" option is selected or no track is currently playing
//            let autoplay: Bool = autoplayPref && (alwaysAutoplay || noPlayingTrack)
//            
//            // Progress
//            let progress = TrackAddOperationProgress(0, files.count, [InvalidTrackError](), false)
//            
//            self.addFiles_sync(files, autoplay, progress)
//            
//            EventRegistry.publishEvent(.doneAddingTracks, DoneAddingTracksEvent.instance)
//            
//            // If errors > 0, send event to UI
//            if (progress.errors.count > 0) {
//                EventRegistry.publishEvent(.tracksNotAdded, TracksNotAddedEvent(progress.errors))
//            }
//        }
//    }
//    
//    // Adds a bunch of files synchronously
//    // The autoplay argument indicates whether or not autoplay is enabled. Make sure to pass it into functions that call back here recursively (addPlaylist() or addDirectory()).
//    // The autoplayed argument indicates whether or not autoplay, if enabled, has already been executed. This value is passed by reference so that recursive calls back here will all see the same value.
//    private func addFiles_sync(_ files: [URL], _ autoplay: Bool, _ progress: TrackAddOperationProgress) {
//        
//        if (files.count > 0) {
//            
//            for _file in files {
//                
//                // Playlists might contain broken file references
//                if (!FileSystemUtils.fileExists(_file)) {
//                    progress.errors.append(FileNotFoundError(_file))
//                    continue
//                }
//                
//                // Always resolve sym links and aliases before reading the file
//                let resolvedFileInfo = FileSystemUtils.resolveTruePath(_file)
//                let file = resolvedFileInfo.resolvedURL
//                
//                if (resolvedFileInfo.isDirectory) {
//                    
//                    // Directory
//                    addDirectory(file, autoplay, progress)
//                    
//                } else {
//                    
//                    // Single file - playlist or track
//                    let fileExtension = file.pathExtension.lowercased()
//                    
//                    if (AppConstants.supportedPlaylistFileTypes.contains(fileExtension)) {
//                        
//                        // Playlist
//                        addPlaylist(file, autoplay, progress)
//                        
//                    } else if (AppConstants.supportedAudioFileTypes.contains(fileExtension)) {
//                        
//                        // Track
//                        do {
//                            
//                            progress.tracksAdded += 1
//                            
//                            let eventProgress = TrackAddedEventProgress(progress.tracksAdded, progress.totalTracks)
//                            let index = try addTrack(file, eventProgress)
//                            
//                            if (autoplay && !progress.autoplayed && index >= 0) {
//                                
//                                self.autoplay(index)
//                                progress.autoplayed = true
//                            }
//                            
//                        }  catch let error as Error {
//                            
//                            if (error is InvalidTrackError) {
//                                progress.errors.append(error as! InvalidTrackError)
//                            }
//                        }
//                        
//                    } else {
//                        
//                        // Unsupported file type, ignore
//                        NSLog("Ignoring unsupported file: %@", file.path)
//                    }
//                }
//            }
//        }
//    }
//    
//    // Returns index of newly added track
//    private func addTrack(_ file: URL, _ progress: TrackAddedEventProgress) throws -> Int {
//        
////        let newTrackIndex = try playlist.addTrack(file)
////        if (newTrackIndex >= 0) {
////            notifyTrackAdded(newTrackIndex, progress)
////            prepareNextTracksForPlayback()
////        }
////        return newTrackIndex
//        return 0
//    }
//    
//    private func addPlaylist(_ playlistFile: URL, _ autoplay: Bool, _ progress: TrackAddOperationProgress) {
//       
//        let loadedPlaylist = PlaylistIO.loadPlaylist(playlistFile)
//        if (loadedPlaylist != nil) {
//            
//            progress.totalTracks -= 1
//            progress.totalTracks += (loadedPlaylist?.tracks.count)!
//            
//            addFiles_sync(loadedPlaylist!.tracks, autoplay, progress)
//        }
//    }
//    
//    private func addDirectory(_ dir: URL, _ autoplay: Bool, _ progress: TrackAddOperationProgress) {
//        
//        let dirContents = FileSystemUtils.getContentsOfDirectory(dir)
//        if (dirContents != nil) {
//            
//            progress.totalTracks -= 1
//            progress.totalTracks += (dirContents?.count)!
//            
//            // Add them
//            addFiles_sync(dirContents!, autoplay, progress)
//        }
//    }
//    
//    // Publishes a notification that a new track has been added to the playlist
//    func notifyTrackAdded(_ trackIndex: Int, _ progress: TrackAddedEventProgress) {
//        
//        let trackAddedEvent = TrackAddedEvent(trackIndex, progress)
//        EventRegistry.publishEvent(.trackAdded, trackAddedEvent)
//    }
//    
//    func removeTrack(_ index: Int) -> Int? {
//        
//        let removingPlayingTrack: Bool = (index == playlist.cursor())
//        playlist.removeTrack(index)
//        
//        // If the removed track is not the playing track, continue playing !
//        if (removingPlayingTrack) {
//            stopPlayback()
//        }
//        
//        // Update playing track index (which may have changed)
//        playingTrack?.index = playlist.cursor()
//        
//        if (playlist.size() > 0) {
//            prepareNextTracksForPlayback()
//        }
//        
//        return playlist.cursor()
//    }
//    
//    func moveTrackDown(_ index: Int) -> Int {
//        
//        var newIndex = index
//        
//        if (index < (playlist.size() - 1)) {
//            playlist.shiftTrackDown(index)
//            
//            // Update playing track index (which may have changed)
//            playingTrack?.index = playlist.cursor()
//            
//            newIndex = index + 1
//        }
//        
//        prepareNextTracksForPlayback()
//        return newIndex
//    }
//    
//    func moveTrackUp(_ index: Int) -> Int {
//        
//        var newIndex = index
//        
//        if (index > 0) {
//            playlist.shiftTrackUp(index)
//            
//            // Update playing track index (which may have changed)
//            playingTrack?.index = playlist.cursor()
//            
//            newIndex = index - 1
//        }
//        
//        prepareNextTracksForPlayback()
//        return newIndex
//    }
//    
//    func clearPlaylist() {
//        stopPlayback()
//        playlist.clear()
//        
//        // This may not be needed
//        trackPrepQueue.cancelAllOperations()
//    }
//    
//    func savePlaylist(_ file: URL) {
//        DispatchQueue.global(qos: .userInitiated).async {
//            PlaylistIO.savePlaylist(file)
//        }
//    }
//    
//    func getPlayingTrack() -> IndexedTrack? {
//        return playingTrack
//    }
//    
//    func summary() -> (numTracks: Int, totalDuration: Double) {
//        return (playlist.size(), playlist.totalDuration())
//    }
//    
//    func getMoreInfo() -> IndexedTrack? {
//        
//        if (playingTrack == nil) {
//            return nil
//        }
//        
//        TrackIO.loadDetailedTrackInfo(playingTrack!.track!)
//        return playingTrack
//    }
//    
//    func togglePlayPause() throws -> (playbackState: PlaybackState, playingTrack: IndexedTrack?, trackChanged: Bool) {
//        
//        var trackChanged = false
//        
//        // Determine current state of player, to then toggle it
//        switch playbackState {
//            
//        case .noTrack: try continuePlaying()
//        if (playingTrack != nil) {
//            trackChanged = true
//        }
//            
//        case .paused: resume()
//            
//        case .playing: pause()
//    
//        }
//        
//        return (playbackState, playingTrack, trackChanged)
//    }
//
//    // Assume valid index
//    func play(_ index: Int) throws -> IndexedTrack {
//        
//        let track = playlist.selectTrackAt(index)!
//        try play(track)
//        
//        return playingTrack!
//    }
//    
//    func stopPlayback() {
//        PlaybackSession.endCurrent()
//        player.stop()
//        playbackState = .noTrack
//        playingTrack = nil
//    }
//    
//    private func continuePlaying() throws -> IndexedTrack? {
//        try play(playlist.continuePlaying())
//        return playingTrack
//    }
//
//    func nextTrack() throws -> IndexedTrack? {
//    
//        let nextTrack = playlist.next()
//        if (nextTrack != nil) {
//            try play(nextTrack)
//        }
//        
//        return nextTrack
//    }
//    
//    func previousTrack() throws -> IndexedTrack? {
//        
//        let prevTrack = playlist.previous()
//        if (prevTrack != nil) {
//            try play(prevTrack)
//        }
//        
//        return prevTrack
//    }
//    
//    private func play(_ track: IndexedTrack?) throws {
//        
//        // Stop if currently playing
//        if (playbackState == .paused || playbackState == .playing) {
//            stopPlayback()
//        }
//        
//        playingTrack = track
//        if (track != nil) {
//            
//            let session = PlaybackSession.start(track!)
//            
//            let actualTrack = track!.track!
//            TrackIO.prepareForPlayback(actualTrack)
//            
//            if (actualTrack.preparationFailed) {
//                throw actualTrack.preparationError!
//            }
//            
//            player.play(session)
//            playbackState = .playing
//            
//            // Prepare next possible tracks for playback
//            prepareNextTracksForPlayback()
//        }
//    }
//    
//    // Computes which tracks are likely to play next (based on the playback sequence and user actions), and eagerly loads metadata for those tracks in preparation for their future playback. This significantly speeds up playback start time when the track is actually played back.
//    private func prepareNextTracksForPlayback() {
//        
//        // Set of all tracks that need to be prepped
//        let nextTracksSet = NSMutableSet()
//        
//        // The three possible tracks that could play next
//        let peekContinue = self.playlist.peekContinuePlaying()?.track
//        let peekNext = self.playlist.peekNext()?.track
//        let peekPrevious = self.playlist.peekPrevious()?.track
//        
//        // Add each of the three tracks to the set of tracks to be prepped, as long as they're non-nil and not equal to the playing track (which has already been prepped, since it is playing)
//        if (peekContinue != nil && playingTrack?.track !== peekContinue) {
//            nextTracksSet.add(peekContinue!)
//        }
//        
//        if (peekNext != nil) {
//            nextTracksSet.add(peekNext!)
//        }
//        
//        if (peekPrevious != nil) {
//            nextTracksSet.add(peekPrevious!)
//        }
//        
//        if (nextTracksSet.count > 0) {
//            
//            for _track in nextTracksSet {
//                
//                let track = _track as! Track
//                
//                // If track has not already been prepped, add a serial async task (to avoid concurrent prepping of the same track by two threads) to the trackPrepQueue
//                
//                // Async execution is important here, because reading from disk could be expensive and this info is not needed immediately.
//                if (!track.preparedForPlayback) {
//                    
//                    let prepOp = BlockOperation(block: {
//                        TrackIO.prepareForPlayback(track)
//                    })
//                    
//                    trackPrepQueue.addOperation(prepOp)
//                }
//            }
//        }
//    }
//    
//    private func pause() {
//        player.pause()
//        playbackState = .paused
//    }
//    
//    private func resume() {
//        player.resume()
//        playbackState = .playing
//    }
//    
//    func getPlaybackState() -> PlaybackState {
//        return playbackState
//    }
//    
//    func getSeekSecondsAndPercentage() -> (seconds: Double, percentage: Double) {
//        
//        let seconds = playingTrack != nil ? player.getSeekPosition() : 0
//        let percentage = playingTrack != nil ? seconds * 100 / playingTrack!.track!.duration! : 0
//        
//        return (seconds, percentage)
//    }
//    
//    func seekForward() {
//        
//        if (playbackState != .playing) {
//            return
//        }
//        
//        // Calculate the new start position
//        let curPosn = player.getSeekPosition()
//        let trackDuration = playingTrack!.track!.duration!
//        let newPosn = min(trackDuration, curPosn + Double(preferences.seekLength))
//        
//        // If this seek takes the track to its end, stop playback and proceed to the next track
//        if (newPosn < trackDuration) {
//            let session = PlaybackSession.start(playingTrack!)
//            player.seekToTime(session, newPosn)
//        } else {
//            trackPlaybackCompleted()
//        }
//    }
//    
//    func seekBackward() {
//        
//        if (playbackState != .playing) {
//            return
//        }
//        
//        // Calculate the new start position
//        let curPosn = player.getSeekPosition()
//        let newPosn = max(0, curPosn - Double(preferences.seekLength))
//        
//        let session = PlaybackSession.start(playingTrack!)
//        player.seekToTime(session, newPosn)
//    }
//    
//    func seekToPercentage(_ percentage: Double) {
//        
//        if (playbackState != .playing) {
//            return
//        }
//        
//        // Calculate the new start position
//        let newPosn = percentage * playingTrack!.track!.duration! / 100
//        let trackDuration = playingTrack!.track!.duration!
//        
//        // If this seek takes the track to its end, stop playback and proceed to the next track
//        if (newPosn < trackDuration) {
//            let session = PlaybackSession.start(playingTrack!)
//            player.seekToTime(session, newPosn)
//        } else {
//            trackPlaybackCompleted()
//        }
//    }
//    
//    func toggleRepeatMode() -> (repeatMode: RepeatMode, shuffleMode: ShuffleMode) {
//        let modes = playlist.toggleRepeatMode()
//        prepareNextTracksForPlayback()
//        return modes
//    }
//    
//    func toggleShuffleMode() -> (repeatMode: RepeatMode, shuffleMode: ShuffleMode) {
//        let modes = playlist.toggleShuffleMode()
//        prepareNextTracksForPlayback()
//        return modes
//    }
//    
//    // Called when playback of the current track completes
//    func consumeEvent(_ event: Event) {
//        
//        let _evt = event as! PlaybackCompletedEvent
//        
//        // Do not accept duplicate/old events
//        if (PlaybackSession.isCurrent(_evt.session)) {
//            trackPlaybackCompleted()
//        }
//    }
//    
//    private func trackPlaybackCompleted() {
//        
//        // Stop playback of the old track
//        stopPlayback()
//        
//        // Continue the playback sequence
//        do {
//            try continuePlaying()
//            
//            playbackState = playingTrack != nil ? .playing : .noTrack
//            
//            // Notify the UI about this track change event
//            EventRegistry.publishEvent(.trackChanged, TrackChangedEvent(playingTrack))
//            
//        } catch let error as Error {
//            
//            if (error is InvalidTrackError) {
//                EventRegistry.publishEvent(.trackNotPlayed, TrackNotPlayedEvent(error as! InvalidTrackError))
//            }
//        }
//    }
//    
//    func searchPlaylist(searchQuery: SearchQuery) -> SearchResults {
//        return playlist.search(searchQuery)
//    }
//    
//    func sortPlaylist(sort: Sort) {
//        playlist.sortPlaylist(sort: sort)
//        
//        // Update playing track index (which may have changed)
//        playingTrack?.index = playlist.cursor()
//        
//        prepareNextTracksForPlayback()
//    }
//    
//    func consumeNotification(_ notification: NotificationMessage) {
//        
//        if (notification is AppLoadedNotification && preferences.playlistOnStartup == .rememberFromLastAppLaunch) {
//            EventRegistry.publishEvent(.startedAddingTracks, StartedAddingTracksEvent.instance)
//            loadPlaylistFromSavedState()
//        }
//    }
//    
//    func processRequest(_ request: RequestMessage) -> ResponseMessage {
//        return EmptyResponse.instance
//    }
//}
//
//// Indicates current progress for an operation that adds tracks to the playlist
//class TrackAddOperationProgress {
//    
//    var tracksAdded: Int
//    var totalTracks: Int
//    var errors: [InvalidTrackError]
//    var autoplayed: Bool
//    
//    init(_ tracksAdded: Int, _ totalTracks: Int, _ errors: [InvalidTrackError], _ autoplayed: Bool) {
//        self.tracksAdded = tracksAdded
//        self.totalTracks = totalTracks
//        self.errors = errors
//        self.autoplayed = autoplayed
//    }
//}
