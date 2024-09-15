library(tidyverse)
library(patchwork)

theme_set(theme_classic())

db      <- file.path("~/Library/CloudStorage/Dropbox/gdp-temp/ma_rep/")
code    <- file.path("~/Documents/GitHub/ma_klw/")
dir.out <- file.path(code, "/outputs/")
setwd(db)

# 0. Load data ------------------------------------------------------------

df <- read_csv('DOSE replication files/Data/fig7_plotdata.csv') %>% 
  mutate(Country = if_else(GID_0== "UZB", "UZB", "Other")) %>% 
  mutate(diff = 100*(grp_pc_ppp_2005 - gennaioli2014) / gennaioli2014) 

# Check UZB values
df %>% filter(Country == "UZB") %>% ggplot() + geom_histogram(aes(x = diff))

df %>% 
  filter(GID_0 == "UZB", !is.na(gennaioli2014)) %>% 
  mutate(year = as.factor(year)) %>% 
  ggplot() + 
  geom_point(aes(x = grp_pc_ppp_2005, y = gennaioli2014, color= year)) + 
  geom_abline()

# 1.1 plot fig7a -----------------------------------------------------------

p1 <- ggplot(df)+ 
  geom_point(aes(x = grp_pc_ppp_2005, y = gennaioli2014), color = 'orange', 
             alpha = .5)+
  coord_fixed() + 
  geom_abline(linetype = 'dashed', color = 'black') +
  xlab("DOSE GRP_PC (2005-PPP-USD)") + 
  ylab("G2014 GRP per capita (2005-PPP-USD)") + 
  geom_rect(xmin = 0, xmax = 60000, ymin = 0, ymax = 60000, 
            fill = "transparent", color = 'red')+
  theme(text = element_text(size=15))
p1

# 1.2 Percent diff between Genaoilli and Dose v2 ---------------------------

p2 <- df %>% 
  # arrange(-abs(diff)) %>% head(100) %>% view()
  ggplot(aes(x = diff)) + 
  stat_ecdf(aes(color = Country))+
  xlab("% diff DOSEv2 and Gennaioli 2014") +    
  theme(legend.position=c(.8,.6), text = element_text(size=15))
p2

# 1.3 Time series for UZB --------------------------------------------------

p3 <- df %>% 
  filter(GID_0 == "UZB") %>% 
  ggplot() + 
  geom_line(aes(x = year, y = grp_pc_ppp_2005)) +
  geom_point(aes(x = year, y = gennaioli2014), color = 'red') + 
  facet_wrap(~region) + 
  xlab("Year") + ylab("GRP Estimate")+
  theme(text = element_text(size=15))+
  scale_x_continuous(breaks = c(1995, 2005, 2015)) +
  scale_y_continuous(breaks = c(0, 20000, 40000))
p3

# 1.4 Combined plot of 1.1-1.3 --------------------------------------------

p1+plot_spacer()+p2+plot_spacer()+p3+ 
  plot_layout(widths = c(1, 0.1, 0.6,0.1, 1))+
  plot_annotation(tag_levels = "a")
# ggsave(filename = paste0(dir.out, "/comment_fig2.pdf"), width = 26, height = 8)

# replicate all panels ----------------------------------------------------

variables <- c('grp_pc_ppp_2005','grp_pc_lcu2005_ppp')
meths     <- c('','_demeaned','_demeaned2','_demeaned3')
labels    <- c('','demeaned by country-year','demeaned by country',
               'demeaned by subnat. region')
lims      <- list(c(0,60000),c(-10000,10000),c(-15000,15000),c(-15000,15000))

# Get a tibble of limits for each panel 
rect.df <- 
  map_dfr(seq_along(variables),
          function(vv){
            var <- variables [vv]
            map_dfr(seq_along(meths), 
                    function(mm){
                      lim <- lims[[mm]]
                      tibble(x=lim[[1]], y=lim[[2]], xlab = var, 
                             ylab = meths[mm], ylab_full = labels[mm])
                      }
            )
            }
          )

plot.df <- 
  map_dfr(
    variables, 
    function(vv){
      map_dfr(
         meths, 
         function(mm){
           df %>% 
             select(xvar = .data[[paste0(vv, mm)]], 
                    yvar = .data[[paste0("gennaioli2014", mm)]], 
                    GID_0) %>% 
             mutate(xlab = !!vv, ylab = !!mm)
         }
      )
    }
  ) %>% 
  mutate(xlab = fct_relevel(xlab, variables)) %>% 
  mutate(Country=ifelse(GID_0 == "UZB", "UZB", "Other"))

ggplot(plot.df %>% filter(GID_0 == "UZB") )+ 
  
  geom_point(aes(x = xvar , 
                 y = yvar, 
                 colour = Country
  ), 
  # color = 'orange', 
  # alpha = .5
  ) +
  # coord_fixed() + 
  geom_abline(linetype = 'dashed', color = 'black') +
  xlab("DOSE GRP_PC (2005-PPP-USD)") + 
  ylab("G2014 GRP per capita (2005-PPP-USD)") + 
  geom_rect(data = rect.df, 
            aes(
            xmin = x, xmax = y, ymin =x, ymax = y
            ),
            fill = "transparent", color = 'red')+
  theme(text = element_text(size=15))+
  facet_wrap(~ylab+xlab, ncol=2, scales='fixed')
