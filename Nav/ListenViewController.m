//
//  NewsViewController.m
//  Radio DePaul
//
//  Created by Devon Blandin on 11/5/12.
//  Copyright (c) 2012 Devon Blandin. All rights reserved.
//

#import "ListenViewController.h"
#import <MediaPlayer/MediaPlayer.h>

@interface ListenViewController ()

@end

@implementation ListenViewController

@synthesize currentArtist, currentTitle;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [self createTimers:YES];
        [self forceUIUpdate];
    }
    return self;
}
- (void) setupUI
{
    [self.view setBackgroundColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"pattern"]]];
}
- (void) getShowData
{
    NSError *e = nil;
    NSString *url = @"http://radiodepaul.herokuapp.com/api/getOnAir.json";
    NSData *data = [[NSData alloc] initWithContentsOfURL:[[NSURL alloc] initWithString:url]];
    NSArray *jsonArray = [NSJSONSerialization JSONObjectWithData: data options: NSJSONReadingMutableContainers error: &e];
    
    if (!jsonArray) {
        NSLog(@"Error parsing JSON: %@", e);
    } else {
        for(NSDictionary *item in jsonArray) {
            NSDictionary *show = [item objectForKey:@"show"];
            //NSDictionary *genres = [show objectForKey:@"genre"];
            NSArray *hosts = [show objectForKey:@"hosts"];
            NSArray *days = [item objectForKey:@"days"];
            
            NSLog(@"%@", [show objectForKey:@"title"]);
            showTitle.text = [show objectForKey:@"title"];
            NSLog(@"%@", [show objectForKey:@"quarter"]);
            NSLog(@"%@", [show objectForKey:@"photo"]);
            NSData *image = [[NSData alloc] initWithContentsOfURL:[[NSURL alloc] initWithString:[show objectForKey:@"photo"]]];
            showImage.image = [[UIImage alloc] initWithData:image];
            [showImage.layer setBorderWidth:5.0f];
            [showImage.layer setBorderColor:[[UIColor whiteColor] CGColor]];
            [showImage.layer setShadowRadius:5.0f];
            [showImage.layer setShadowOpacity:.85f];
            [showImage.layer setShadowOffset:CGSizeMake(1.0f, 2.0f)];
            [showImage.layer setShadowColor:[[UIColor blackColor] CGColor]];
            [showImage.layer setShouldRasterize:YES];
            [showImage.layer setMasksToBounds:NO];
            
            NSLog(@"%@", [show objectForKey:@"id"]);
            
            NSString *genresString = @"";
            //for(NSString *genre in genres)
            //{
            //    NSLog(@"%@", genre);
            //    genresString = [genresString stringByAppendingString:[NSString stringWithFormat:@"%@ ", genre]];
            //}
            showGenres.text = genresString;
            
            for(NSString *day in days)
            {
                NSLog(@"%@", day);
            }
            
            for(NSDictionary *host in hosts)
            {
                NSLog(@"%@", [host objectForKey:@"name"]);
                NSLog(@"%@", [host objectForKey:@"id"]);
                NSLog(@"%@", [host objectForKey:@"photo_thumb"]);
            }
            NSLog(@"%@", [show objectForKey:@"short_description"]);
            showDescription.text = [show objectForKey:@"short_description"];
            
            NSLog(@"%@", [item objectForKey:@"start_time"]);
            NSLog(@"%@", [item objectForKey:@"end_time"]);
            showStartTime.text = [item objectForKey:@"start_time"];
            showEndTime.text = [item objectForKey:@"end_time"];
            
            
        }
    }
}

//
// setButtonImage:
//
// Used to change the image on the playbutton. This method exists for
// the purpose of inter-thread invocation because
// the observeValueForKeyPath:ofObject:change:context: method is invoked
// from secondary threads and UI updates are only permitted on the main thread.
//
// Parameters:
//    image - the image to set on the play button.
//
- (void)setButtonImage:(UIImage *)image
{
	[button.layer removeAllAnimations];
	if (!image)
	{
		[button setImage:[UIImage imageNamed:@"playbutton.png"] forState:0];
	}
	else
	{
		[button setImage:image forState:0];
        
		if ([button.currentImage isEqual:[UIImage imageNamed:@"loadingbutton.png"]])
		{
			[self spinButton];
		}
	}
}

//
// destroyStreamer
//
// Removes the streamer, the UI update timer and the change notification
//
- (void)destroyStreamer
{
	if (streamer)
	{
		[[NSNotificationCenter defaultCenter]
         removeObserver:self
         name:ASStatusChangedNotification
         object:streamer];
		[self createTimers:NO];
		
		[streamer stop];
		streamer = nil;
	}
}

//
// forceUIUpdate
//
// When foregrounded force UI update since we didn't update in the background
//
-(void)forceUIUpdate {
	if (currentArtist)
		metadataArtist.text = currentArtist;
	if (currentTitle)
		metadataTitle.text = currentTitle;
    
	if (!streamer) {
		[levelMeterView updateMeterWithLeftValue:0.0
									  rightValue:0.0];
		[self setButtonImage:[UIImage imageNamed:@"playbutton.png"]];
	}
	else
		[self playbackStateChanged:NULL];
}

//
// createTimers
//
// Creates or destoys the timers
//
-(void)createTimers:(BOOL)create {
	if (create) {
		if (streamer) {
            [self createTimers:NO];
            progressUpdateTimer =
            [NSTimer
             scheduledTimerWithTimeInterval:0.1
             target:self
             selector:@selector(updateProgress:)
             userInfo:nil
             repeats:YES];
            levelMeterUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:.1
                                                                     target:self
                                                                   selector:@selector(updateLevelMeters:)
                                                                   userInfo:nil
                                                                    repeats:YES];
		}
	}
	else {
		if (progressUpdateTimer)
		{
			[progressUpdateTimer invalidate];
			progressUpdateTimer = nil;
		}
		if(levelMeterUpdateTimer) {
			[levelMeterUpdateTimer invalidate];
			levelMeterUpdateTimer = nil;
		}
	}
}

//
// createStreamer
//
// Creates or recreates the AudioStreamer object.
//
- (void)createStreamer
{
	if (streamer)
	{
		return;
	}
    
	[self destroyStreamer];
    
	NSURL *url = [NSURL URLWithString:@"http://rock.radio.depaul.edu:8000"];
	streamer = [[AudioStreamer alloc] initWithURL:url];
	
	[self createTimers:YES];
    
	[[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(playbackStateChanged:)
     name:ASStatusChangedNotification
     object:streamer];
#ifdef SHOUTCAST_METADATA
	[[NSNotificationCenter defaultCenter]
	 addObserver:self
	 selector:@selector(metadataChanged:)
	 name:ASUpdateMetadataNotification
	 object:streamer];
#endif
}

//
// viewDidLoad
//
// Creates the volume slider, sets the default path for the local file and
// creates the streamer immediately if we already have a file at the local
// location.
//
- (void)viewDidLoad
{
	[super viewDidLoad];
    [TestFlight passCheckpoint:@"Visited Listen View"];
	
    
    [self getShowData];
    MPVolumeView *volumeView = [[MPVolumeView alloc] initWithFrame:volumeSlider.bounds];
	[volumeSlider addSubview:volumeView];
	[volumeView sizeToFit];
	
	[self setButtonImage:[UIImage imageNamed:@"playbutton.png"]];
	
	levelMeterView = [[LevelMeterView alloc] initWithFrame:CGRectMake(10.0, 280.0, 300.0, 60.0)];
	[self.view addSubview:levelMeterView];
}

- (void)viewDidUnload
{
    showEndTime = nil;
    showStartTime = nil;
    showImage = nil;
    showDescription = nil;
    showGenres = nil;
    showTitle = nil;
    volumeSlider = nil;
    volumeSlider = nil;
    volumeSlider = nil;
    [self createTimers:NO];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	UIApplication *application = [UIApplication sharedApplication];
	if([application respondsToSelector:@selector(beginReceivingRemoteControlEvents)])
		[application beginReceivingRemoteControlEvents];
	[self becomeFirstResponder]; // this enables listening for events
	// update the UI in case we were in the background
	NSNotification *notification =
	[NSNotification
	 notificationWithName:ASStatusChangedNotification
	 object:self];
	[[NSNotificationCenter defaultCenter]
	 postNotification:notification];
}

- (BOOL)canBecomeFirstResponder {
	return YES;
}

//
// spinButton
//
// Shows the spin button when the audio is loading. This is largely irrelevant
// now that the audio is loaded from a local file.
//
- (void)spinButton
{
	[CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
	CGRect frame = [button frame];
	button.layer.anchorPoint = CGPointMake(0.5, 0.5);
	button.layer.position = CGPointMake(frame.origin.x + 0.5 * frame.size.width, frame.origin.y + 0.5 * frame.size.height);
	[CATransaction commit];
    
	[CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanFalse forKey:kCATransactionDisableActions];
	[CATransaction setValue:[NSNumber numberWithFloat:2.0] forKey:kCATransactionAnimationDuration];
    
	CABasicAnimation *animation;
	animation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
	animation.fromValue = [NSNumber numberWithFloat:0.0];
	animation.toValue = [NSNumber numberWithFloat:2 * M_PI];
	animation.timingFunction = [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionLinear];
	animation.delegate = self;
	[button.layer addAnimation:animation forKey:@"rotationAnimation"];
    
	[CATransaction commit];
}

//
// animationDidStop:finished:
//
// Restarts the spin animation on the button when it ends. Again, this is
// largely irrelevant now that the audio is loaded from a local file.
//
// Parameters:
//    theAnimation - the animation that rotated the button.
//    finished - is the animation finised?
//
- (void)animationDidStop:(CAAnimation *)theAnimation finished:(BOOL)finished
{
	if (finished)
	{
		[self spinButton];
	}
}

//
// buttonPressed:
//
// Handles the play/stop button. Creates, observes and starts the
// audio streamer when it is a play button. Stops the audio streamer when
// it isn't.
//
// Parameters:
//    sender - normally, the play/stop button.
//
- (IBAction)buttonPressed:(id)sender
{
	if ([button.currentImage isEqual:[UIImage imageNamed:@"playbutton.png"]] || [button.currentImage isEqual:[UIImage imageNamed:@"pausebutton.png"]])
	{
		[downloadSourceField resignFirstResponder];
		
		[self createStreamer];
		[self setButtonImage:[UIImage imageNamed:@"loadingbutton.png"]];
		[streamer start];
        [TestFlight passCheckpoint:@"Played the stream"];
        if ([MPNowPlayingInfoCenter class])  {
            /* we're on iOS 5, so set up the now playing center */
            MPMediaItemArtwork *albumArt = [[MPMediaItemArtwork alloc] initWithImage:showImage.image];
            
            NSDictionary *currentlyPlayingTrackInfo = [NSDictionary dictionaryWithObjects:[NSArray arrayWithObjects:showTitle.text, albumArt, nil] forKeys:[NSArray arrayWithObjects:MPMediaItemPropertyTitle, MPMediaItemPropertyArtwork, nil]];
            [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = currentlyPlayingTrackInfo;
        }
	}
	else
	{
		[streamer stop];
        [TestFlight passCheckpoint:@"Stopped the stream"];
	}
}

//
// sliderMoved:
//
// Invoked when the user moves the slider
//
// Parameters:
//    aSlider - the slider (assumed to be the progress slider)
//
- (IBAction)sliderMoved:(UISlider *)aSlider
{
	if (streamer.duration)
	{
		double newSeekTime = (aSlider.value / 100.0) * streamer.duration;
		[streamer seekToTime:newSeekTime];
	}
}

//
// playbackStateChanged:
//
// Invoked when the AudioStreamer
// reports that its playback status has changed.
//
- (void)playbackStateChanged:(NSNotification *)aNotification
{
	AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
    
	if ([streamer isWaiting])
	{
		if (appDelegate.uiIsVisible) {
			[levelMeterView updateMeterWithLeftValue:0.0
                                          rightValue:0.0];
			[streamer setMeteringEnabled:NO];
			[self setButtonImage:[UIImage imageNamed:@"loadingbutton.png"]];
		}
	}
	else if ([streamer isPlaying])
	{
		if (appDelegate.uiIsVisible) {
			[streamer setMeteringEnabled:YES];
			[self setButtonImage:[UIImage imageNamed:@"stopbutton.png"]];
		}
	}
	else if ([streamer isPaused]) {
		if (appDelegate.uiIsVisible) {
			[levelMeterView updateMeterWithLeftValue:0.0
                                          rightValue:0.0];
			[streamer setMeteringEnabled:NO];
			[self setButtonImage:[UIImage imageNamed:@"pausebutton.png"]];
		}
	}
	else if ([streamer isIdle])
	{
		if (appDelegate.uiIsVisible) {
			[levelMeterView updateMeterWithLeftValue:0.0
                                          rightValue:0.0];
			[self setButtonImage:[UIImage imageNamed:@"playbutton.png"]];
		}
		[self destroyStreamer];
	}
}

#ifdef SHOUTCAST_METADATA
/** Example metadata
 *
 StreamTitle='Kim Sozzi / Amuka / Livvi Franc - Secret Love / It's Over / Automatik',
 StreamUrl='&artist=Kim%20Sozzi%20%2F%20Amuka%20%2F%20Livvi%20Franc&title=Secret%20Love%20%2F%20It%27s%20Over%20%2F%20Automatik&album=&duration=1133453&songtype=S&overlay=no&buycd=&website=&picture=',
 
 Format is generally "Artist hypen Title" although servers may deliver only one. This code assumes 1 field is artist.
 */
- (void)metadataChanged:(NSNotification *)aNotification
{
	NSString *streamArtist;
	NSString *streamTitle;
	NSString *streamAlbum;
    //NSLog(@"Raw meta data = %@", [[aNotification userInfo] objectForKey:@"metadata"]);
    
	NSArray *metaParts = [[[aNotification userInfo] objectForKey:@"metadata"] componentsSeparatedByString:@";"];
	NSString *item;
	NSMutableDictionary *hash = [[NSMutableDictionary alloc] init];
	for (item in metaParts) {
		// split the key/value pair
		NSArray *pair = [item componentsSeparatedByString:@"="];
		// don't bother with bad metadata
		if ([pair count] == 2)
			[hash setObject:[pair objectAtIndex:1] forKey:[pair objectAtIndex:0]];
	}
    
	// do something with the StreamTitle
	NSString *streamString = [[hash objectForKey:@"StreamTitle"] stringByReplacingOccurrencesOfString:@"'" withString:@""];
	
	NSArray *streamParts = [streamString componentsSeparatedByString:@" - "];
	if ([streamParts count] > 0) {
		streamArtist = [streamParts objectAtIndex:0];
	} else {
		streamArtist = @"";
	}
	// this looks odd but not every server will have all artist hyphen title
	if ([streamParts count] >= 2) {
		streamTitle = [streamParts objectAtIndex:1];
		if ([streamParts count] >= 3) {
			streamAlbum = [streamParts objectAtIndex:2];
		} else {
			streamAlbum = @"N/A";
		}
	} else {
		streamTitle = @"";
		streamAlbum = @"";
	}
	NSLog(@"%@ by %@ from %@", streamTitle, streamArtist, streamAlbum);
    
	// only update the UI if in foreground
	AppDelegate *appDelegate = [[UIApplication sharedApplication] delegate];
	if (appDelegate.uiIsVisible) {
		metadataArtist.text = streamArtist;
		metadataTitle.text = streamTitle;
		metadataAlbum.text = streamAlbum;
	}
	self.currentArtist = streamArtist;
	self.currentTitle = streamTitle;
}
#endif

//
// updateProgress:
//
// Invoked when the AudioStreamer
// reports that its playback progress has changed.
//
- (void)updateProgress:(NSTimer *)updatedTimer
{
	if (streamer.bitRate != 0.0)
	{
		double progress = streamer.progress;
		double duration = streamer.duration;
		
		if (duration > 0)
		{
			[positionLabel setText:
             [NSString stringWithFormat:@"Time Played: %.1f/%.1f seconds",
              progress,
              duration]];
			[progressSlider setEnabled:YES];
			[progressSlider setValue:100 * progress / duration];
		}
		else
		{
			[progressSlider setEnabled:NO];
		}
	}
	else
	{
		positionLabel.text = @"Time Played:";
	}
}


//
// updateLevelMeters:
//

- (void)updateLevelMeters:(NSTimer *)timer {
	AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
	if([streamer isMeteringEnabled] && appDelegate.uiIsVisible) {
		[levelMeterView updateMeterWithLeftValue:[streamer averagePowerForChannel:0]
									  rightValue:[streamer averagePowerForChannel:([streamer numberOfChannels] > 1 ? 1 : 0)]];
	}
}


//
// textFieldShouldReturn:
//
// Dismiss the text field when done is pressed
//
// Parameters:
//    sender - the text field
//
// returns YES
//
- (BOOL)textFieldShouldReturn:(UITextField *)sender
{
	[sender resignFirstResponder];
	[self createStreamer];
	return YES;
}

//
// dealloc
//
// Releases instance memory.
//
- (void)dealloc
{
	[self destroyStreamer];
	[self createTimers:NO];
}

#pragma mark Remote Control Events
/* The iPod controls will send these events when the app is in the background */
- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
	switch (event.subtype) {
		case UIEventSubtypeRemoteControlTogglePlayPause:
			[streamer pause];
            [TestFlight passCheckpoint:@"Toggled play/pause from iPod controls"];
			break;
		case UIEventSubtypeRemoteControlPlay:
			[streamer start];
            [TestFlight passCheckpoint:@"Played from iPod controls"];
			break;
		case UIEventSubtypeRemoteControlPause:
			[streamer pause];
            [TestFlight passCheckpoint:@"Paused from iPod controls"];
			break;
		case UIEventSubtypeRemoteControlStop:
			[streamer stop];
            [TestFlight passCheckpoint:@"Stopped from iPod controls"];
			break;
		default:
			break;
	}
}

@end
