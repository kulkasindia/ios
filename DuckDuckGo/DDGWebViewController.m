//
//  DDGWebViewController.m
//  DuckDuckGo2
//
//  Created by Chris Heimark on 12/10/11.
//  Copyright (c) 2011 DuckDuckGo, Inc. All rights reserved.
//

#import "DDGWebViewController.h"

@interface DDGWebViewController (Private)
-(void)moveAddressBarIntoWebView:(BOOL)inside animated:(BOOL)animated;
@end

@implementation DDGWebViewController

@synthesize searchController;
@synthesize webView;
@synthesize params;

#pragma mark - View lifecycle

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];

	webView.delegate = self;
	webView.scalesPageToFit = YES;
	webViewLoadingDepth = 0;
    webView.backgroundColor = [UIColor colorWithRed:0.216 green:0.231 blue:0.235 alpha:1.000];
    
	self.searchController = [[DDGSearchController alloc] initWithNibName:@"DDGSearchController" view:self.view];
    [self moveAddressBarIntoWebView:YES animated:NO];
    
	searchController.searchHandler = self;
    searchController.state = DDGSearchControllerStateWeb;
    [searchController.searchButton setImage:[UIImage imageNamed:@"back_button.png"] forState:UIControlStateNormal];

    // if we already have a query or URL to load, load it.
	viewsInitialized = YES;
    if(queryOrURLToLoad)
        [self loadQueryOrURL:queryOrURLToLoad];
}

- (void)dealloc
{
	[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
	if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
	{
	    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
	}
	return YES;
}

-(void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [searchController willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
}

#pragma mark - Address bar positioning

-(void)moveAddressBarIntoWebView:(BOOL)inside animated:(BOOL)animated {
    static CGFloat headerHeight = 44.0;
    
    // move the webview itself up/down to accomodate the header
    CGRect f = webView.frame;
    CGFloat offset = (inside ? -1.0 : 1.0)*headerHeight;
    f.origin.y += offset;
    f.size.height -= offset;
    webView.frame = f;
    
    // find the largest (tallest) subview
    UIView *mainSubview;
    for(int i=0; i < webView.scrollView.subviews.count; i++) {
        UIView *subview = [[webView.scrollView subviews] objectAtIndex:i];
        if(!mainSubview || subview.frame.size.height > mainSubview.frame.size.height)
            mainSubview = subview;
    }
    
    // push the main subview up/down to accomodate the header
    f = mainSubview.frame;
    f.origin.y += (inside ? 1.0 : -1.0)*headerHeight;
    mainSubview.frame = f;
    
    // and now actually add the search controller in
    [searchController.view removeFromSuperview];
    if(inside) {
        [webView.scrollView addSubview:searchController.view];
        [webView.scrollView bringSubviewToFront:searchController.view];
    } else {
        [self.view addSubview:searchController.view];
    }
}

#pragma mark - Search handler

-(void)searchControllerLeftButtonPressed {
	if(webView.canGoBack)
        [webView goBack];
	else
	    [self.navigationController popViewControllerAnimated:NO];
}

-(void)searchControllerStopOrReloadButtonPressed {
    if(webView.isLoading)
        [webView stopLoading];
    else
        [webView reload];
}

-(void)loadQueryOrURL:(NSString *)queryOrURLString {
    if(!viewsInitialized) {
        // if views haven't loaded yet, nothing below work, so we need to save the URL/query to load later
        queryOrURLToLoad = queryOrURLString;
    } else if(queryOrURLString) {
        NSString *urlString;
        if([searchController isQuery:queryOrURLString]) {
            urlString = [NSString stringWithFormat:@"https://duckduckgo.com/?q=%@&ko=-1", [queryOrURLString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        } else
            urlString = [searchController validURLStringFromString:queryOrURLString];
        
        NSURL *url = [NSURL URLWithString:urlString];
        [webView loadRequest:[NSURLRequest requestWithURL:url]];
        [searchController updateBarWithURL:url];
    }
}

#pragma mark - Web view deleagte

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    
    if([request.URL isEqual:request.mainDocumentURL])
        [searchController updateBarWithURL:request.URL];

	return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)theWebView
{
	if (++webViewLoadingDepth == 1) {
		[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
        [searchController webViewStartedLoading];
        [self moveAddressBarIntoWebView:NO animated:YES];
    }
}

- (void)webViewDidFinishLoad:(UIWebView *)theWebView
{
	if (--webViewLoadingDepth <= 0) {
		[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        [searchController webViewFinishedLoading];
		webViewLoadingDepth = 0;
        [self moveAddressBarIntoWebView:YES animated:YES];
	}
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
	if (--webViewLoadingDepth <= 0) {
		[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        [searchController webViewFinishedLoading];
		webViewLoadingDepth = 0;
        [self moveAddressBarIntoWebView:YES animated:YES];
	}
}

@end
